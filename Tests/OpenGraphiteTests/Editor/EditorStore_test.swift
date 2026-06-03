import Testing
import Foundation
@testable import OpenGraphite

/// 論理名（日本語）: エディターストア関連のテストスイート
/// 概要: DOM payload の取り込み、選択解除、CSS 変数 mutation の状態更新を確認します。
@MainActor
@Suite("エディターストア関連のテストスイート")
struct EditorStoreTests {
    /// 論理名（日本語）: DOM payload 取り込みテスト
    /// 概要: JavaScript から渡された辞書配列が OpenGraphiteNode に変換されることを検証します。
    @Test("DOM payloadをノード一覧へ変換できる")
    func testIngestNodePayloadCreatesNodes() {
        // コンディション：data-og-id を持つ DOM payload を用意する
        let store = EditorStore()
        let payload: [[String: Any]] = [
            [
                "id": "hero",
                "tagName": "herosection",
                "type": "frame",
                "layout": "horizontal",
                "role": "landing-hero",
                "componentID": "site-header",
                "componentKind": "",
                "sourceComponentID": "site-header",
                "sourceInstanceID": "header-instance",
                "cssVariables": ["--og-gap": "32px"],
                "hidden": false,
                "locked": true,
                "depth": 1
            ]
        ]

        // 検証内容：payload を取り込む
        store.ingestNodePayload(payload)

        // 期待値：ノードの基本情報と CSS 変数が保持される
        #expect(store.nodes.count == 1)
        #expect(store.nodes[0].id == "hero")
        #expect(store.nodes[0].layout == "horizontal")
        #expect(store.nodes[0].role == "landing-hero")
        #expect(store.nodes[0].componentID == "site-header")
        #expect(store.nodes[0].sourceComponentID == "site-header")
        #expect(store.nodes[0].sourceInstanceID == "header-instance")
        #expect(store.nodes[0].cssVariables["--og-gap"] == "32px")
        #expect(store.nodes[0].isLocked == true)
    }

    /// 論理名（日本語）: 存在しない選択解除テスト
    /// 概要: 再取り込み後に選択中ノードが存在しない場合、選択が解除されることを検証します。
    @Test("再取り込み後に存在しない選択を解除する")
    func testIngestNodePayloadClearsMissingSelection() {
        // コンディション：選択済みノードとは別の DOM payload を用意する
        let store = EditorStore()
        store.selectNode(id: "old-node")
        let payload: [[String: Any]] = [
            [
                "id": "new-node",
                "tagName": "frame",
                "type": "frame",
                "depth": 0
            ]
        ]

        // 検証内容：payload を取り込む
        store.ingestNodePayload(payload)

        // 期待値：存在しない old-node の選択が解除される
        #expect(store.selectedNodeID == nil)
    }

    /// 論理名（日本語）: ページ選択解除テスト
    /// 概要: ページ選択を nil にすると先頭ページへ戻らず未選択状態になることを検証します。
    @Test("ページ選択を解除できる")
    func testSelectPageNilClearsPageSelection() throws {
        // コンディション：プロジェクトを開き、ページとノードが選択されている状態を用意する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        store.ingestNodePayload([
            [
                "id": "title",
                "tagName": "title",
                "type": "text",
                "depth": 0
            ]
        ])
        store.selectNode(id: "title")

        // 検証内容：ページ選択を解除する
        store.selectPage(id: nil)

        // 期待値：選択ページ、選択ノード、ページ由来のノード一覧が空になる
        #expect(store.selectedPageID == nil)
        #expect(store.selectedPage == nil)
        #expect(store.selectedPageURL == nil)
        #expect(store.selectedNodeID == nil)
        #expect(store.nodes.isEmpty)
        #expect(store.canUndo == false)
        #expect(store.canRedo == false)
        #expect(store.statusMessage == "ページ選択を解除しました。")
    }

    /// 論理名（日本語）: 同一ページ再選択時のノード保持テスト
    /// 概要: 左カラムで同じ HTML カードを再度開いたとき、収集済み DOM ノード一覧が空にならないことを検証します。
    @Test("同じページの再選択ではノード一覧を保持する")
    func testSelectPagePreservesNodesWhenSelectingSamePageAgain() throws {
        // コンディション：プロジェクトを開き、選択ページの DOM ノード一覧が収集済みの状態を用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        store.ingestNodePayload([
            [
                "id": "title",
                "tagName": "title",
                "type": "text",
                "depth": 0
            ]
        ])
        store.selectNode(id: "title")

        // 検証内容：左カラムで同じページカードを再選択する想定で内部 ID による selectPage を再実行する（When）
        let selectedPageInternalID = try #require(store.selectedPage?.internalID)
        store.selectPage(internalID: selectedPageInternalID)

        // 期待値：ページ内ノード一覧は保持され、ノード選択だけが解除される（Then）
        #expect(store.selectedPageID == "home")
        #expect(store.selectedNodeID == nil)
        #expect(store.nodes.map(\.id) == ["title"])
        #expect(store.statusMessage == "index.html を表示しています。")
    }

    /// 論理名（日本語）: 同一Chapter再選択時のノード保持テスト
    /// 概要: Chapters パネルで現在の Chapter を押しても、同じ HTML のレイヤー一覧が空にならないことを検証します。
    @Test("同じChapterの再選択ではノード一覧を保持する")
    func testSelectChapterPreservesNodesWhenSelectingSamePageAgain() throws {
        // コンディション：プロジェクトを開き、選択ページの DOM ノード一覧が収集済みの状態を用意する（Given）
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        store.ingestNodePayload([
            [
                "id": "title",
                "tagName": "title",
                "type": "text",
                "depth": 0
            ]
        ])
        store.selectNode(id: "title")

        // 検証内容：Chapters パネルで現在の Chapter を再選択する想定で selectChapter を再実行する（When）
        let selectedChapterInternalID = try #require(store.selectedChapter?.internalID)
        store.selectChapter(internalID: selectedChapterInternalID)

        // 期待値：同じ page のノード一覧は保持され、ノード選択だけが解除される（Then）
        #expect(store.selectedPageID == "home")
        #expect(store.selectedNodeID == nil)
        #expect(store.nodes.map(\.id) == ["title"])
        #expect(store.statusMessage == "Main を表示しています。")
    }

    /// 論理名（日本語）: 選択ページキャンバス配置保存テスト
    /// 概要: 選択中ページの座標と解像度が Store と `.ogp` に保存されることを検証します。
    @Test("選択ページのキャンバス配置をogpへ保存する")
    func testUpdateSelectedPageCanvasPersistsManifest() throws {
        // Given: 一時プロジェクトを開き、選択ページの新しい配置値を用意する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let expectedCanvas = OpenGraphiteCanvas(x: 24, y: -12, width: 390, height: 844)

        // When: 選択ページのキャンバス配置を更新する
        store.updateSelectedPageCanvas(
            x: expectedCanvas.x,
            y: expectedCanvas.y,
            width: expectedCanvas.width,
            height: expectedCanvas.height
        )

        // Then: Store とディスク上の `.ogp` が同じ配置値になる
        #expect(store.selectedPage?.canvas == expectedCanvas)
        let reloadedProject = try ProjectLoader().loadProject(at: fixture.projectURL)
        let persistedPage = try #require(reloadedProject.project.allPages.first)
        #expect(persistedPage.canvas == expectedCanvas)
        #expect(store.statusMessage.contains("キャンバス配置を更新"))
    }

    /// 論理名（日本語）: 選択ページキャンバス配置名保存テスト
    /// 概要: 選択中ページの任意配置名が Store と `.ogp` に保存され、座標だけの更新では保持されることを検証します。
    @Test("選択ページのキャンバス配置名をogpへ保存する")
    func testUpdateSelectedPageCanvasPersistsName() throws {
        // Given: 一時プロジェクトを開き、フロー解決用の配置名を用意する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)

        // When: 選択ページの配置名とキャンバス配置を更新する
        store.updateSelectedPageCanvas(x: 24, y: -12, width: 390, height: 844, name: " mobile ")

        // Then: Store とディスク上の `.ogp` が trim 済み配置名を保持する
        #expect(store.selectedPage?.canvas.name == "mobile")
        var reloadedProject = try ProjectLoader().loadProject(at: fixture.projectURL)
        var persistedPage = try #require(reloadedProject.project.allPages.first)
        #expect(persistedPage.canvas.name == "mobile")

        // When: 従来の座標更新 API で配置だけを更新する
        store.updateSelectedPageCanvas(x: 40, y: 0, width: 414, height: 896)

        // Then: 既存の配置名は消えずに保持される
        #expect(store.selectedPage?.canvas.name == "mobile")
        reloadedProject = try ProjectLoader().loadProject(at: fixture.projectURL)
        persistedPage = try #require(reloadedProject.project.allPages.first)
        #expect(persistedPage.canvas.name == "mobile")
        #expect(persistedPage.canvas.width == 414)
    }

    /// 論理名（日本語）: 不正キャンバス配置拒否テスト
    /// 概要: 解像度が 0 以下の場合に Store と `.ogp` を更新しないことを検証します。
    @Test("不正な解像度ではキャンバス配置を更新しない")
    func testUpdateSelectedPageCanvasRejectsInvalidResolution() throws {
        // Given: 一時プロジェクトを開き、現在のキャンバス配置を保持する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let originalCanvas = try #require(store.selectedPage?.canvas)

        // When: width 0 の不正な配置を適用しようとする
        store.updateSelectedPageCanvas(x: 0, y: 0, width: 0, height: 844)

        // Then: Store とディスク上の `.ogp` は変更されず、エラーが残る
        #expect(store.selectedPage?.canvas == originalCanvas)
        let reloadedProject = try ProjectLoader().loadProject(at: fixture.projectURL)
        let persistedPage = try #require(reloadedProject.project.allPages.first)
        #expect(persistedPage.canvas == originalCanvas)
        #expect(store.lastError == "キャンバス配置の入力が不正です。")
    }

    /// 論理名（日本語）: CSS変数更新テスト
    /// 概要: 選択中ノードの CSS 変数更新と mutation 発行を検証します。
    @Test("CSS変数更新でノードとmutationを更新する")
    func testUpdateCSSVariableMutatesSelectedNode() {
        // コンディション：選択中ノードを持つストアを用意する
        let store = EditorStore()
        store.ingestNodePayload([
            [
                "id": "hero",
                "tagName": "herosection",
                "type": "frame",
                "cssVariables": ["--og-gap": "16px"],
                "depth": 0
            ]
        ])
        store.selectNode(id: "hero")

        // 検証内容：CSS 変数を空白付きの値で更新する
        store.updateCSSVariable(key: "--og-gap", value: " 32px ")

        // 期待値：値は trim され、WebView 反映用 mutation が発行される
        #expect(store.nodes[0].cssVariables["--og-gap"] == "32px")
        #expect(store.cssMutation?.nodeID == "hero")
        #expect(store.cssMutation?.key == "--og-gap")
        #expect(store.cssMutation?.value == "32px")
    }

    /// 論理名（日本語）: CSS変数同値更新抑制テスト
    /// 概要: フォーカスアウト時の再確定で同じ CSS 値の mutation が増えないことを検証します。
    @Test("同じCSS変数値の再適用ではmutationを発行しない")
    func testUpdateCSSVariableSkipsUnchangedValue() {
        // コンディション：既存 CSS 変数を持つ選択中ノードを用意する
        let store = EditorStore()
        store.ingestNodePayload([
            [
                "id": "hero",
                "tagName": "herosection",
                "type": "frame",
                "cssVariables": ["--og-gap": "16px"],
                "depth": 0
            ]
        ])
        store.selectNode(id: "hero")

        // 検証内容：同じ値を空白付きで再適用する
        store.updateCSSVariable(key: "--og-gap", value: " 16px ")

        // 期待値：値は変わらず、WebView 反映用 mutation も発行されない
        #expect(store.nodes[0].cssVariables["--og-gap"] == "16px")
        #expect(store.cssMutation == nil)
    }

    /// 論理名（日本語）: ノード属性同値更新抑制テスト
    /// 概要: フォーカスアウト時の再確定で同じ属性値の mutation が増えないことを検証します。
    @Test("同じノード属性値の再適用ではmutationを発行しない")
    func testUpdateNodeAttributeSkipsUnchangedValue() {
        // コンディション：role を持つ選択中ノードを用意する
        let store = EditorStore()
        store.ingestNodePayload([
            [
                "id": "title",
                "tagName": "maintitle",
                "type": "text",
                "role": "title",
                "depth": 0
            ]
        ])
        store.selectNode(id: "title")

        // 検証内容：同じ role を空白付きで再適用する
        store.updateNodeAttribute(name: "data-og-role", value: " title ")

        // 期待値：属性は変わらず、WebView 反映用 mutation も発行されない
        #expect(store.nodes[0].role == "title")
        #expect(store.attributeMutation == nil)
    }

    /// 論理名（日本語）: 複合CSS変数更新テスト
    /// 概要: CSS shorthand や関数値を分解せず、HTML 正本へ戻す値としてそのまま保持することを検証します。
    @Test("複合CSS値をStoreで正規化しすぎずmutationへ渡せる")
    func testUpdateCSSVariablePreservesStructuredCSSValues() {
        // コンディション：選択中ノードと、Inspector UI が parse / edit / serialize する CSS 値を用意する
        let store = EditorStore()
        store.ingestNodePayload([
            [
                "id": "preview-card",
                "tagName": "editorpreview",
                "type": "frame",
                "cssVariables": [String: String](),
                "depth": 0
            ]
        ])
        store.selectNode(id: "preview-card")
        let cases: [(key: String, value: String)] = [
            ("--og-width", "min(100%,560px)"),
            ("--og-padding", "14px 20px"),
            ("--og-background", "linear-gradient(135deg,#ffffff 0%,#e9fbf5 54%,#fff3d6 100%)"),
            ("--og-flex", "1 1 0")
        ]

        // 検証内容：各 CSS 値を Store に適用する
        for item in cases {
            store.updateCSSVariable(key: item.key, value: item.value)

            // 期待値：Store は CSS 値を分解・独自正規化せず、そのまま mutation とノード状態へ保持する
            #expect(store.nodes[0].cssVariables[item.key] == item.value)
            #expect(store.cssMutation?.nodeID == "preview-card")
            #expect(store.cssMutation?.key == item.key)
            #expect(store.cssMutation?.value == item.value)
        }
    }

    /// 論理名（日本語）: 同期履歴ディスク反映テスト
    /// 概要: HTML 同期履歴の取り消し・やり直しがディスク内容と WebView 置換要求へ反映されることを検証します。
    @Test("同期履歴の取り消しとやり直しをディスクへ反映する")
    func testUndoRedoDocumentSyncReflectsDiskAndReplacementRequest() throws {
        // コンディション：一時プロジェクトを開き、HTML を二回同期する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)

        store.syncCurrentHTML("<!doctype html>\n<html><body>first</body></html>")
        store.syncCurrentHTML("<!doctype html>\n<html><body>second</body></html>")

        // 検証内容：取り消しを実行する
        store.undoDocumentChange()
        let undoDiskHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：ディスクと WebView 置換要求が一つ前の同期スナップショットになる
        #expect(undoDiskHTML == "<!doctype html>\n<html><body>first</body></html>")
        #expect(store.documentReplacementRequest?.html == "<!doctype html>\n<html><body>first</body></html>")
        #expect(store.canRedo == true)

        guard let undoSequence = store.documentReplacementRequest?.sequence else {
            Issue.record("取り消し後の置換要求がありません。")
            return
        }
        store.markDocumentReplacementApplied(sequence: undoSequence)

        // 検証内容：やり直しを実行する
        store.redoDocumentChange()
        let redoDiskHTML = try String(contentsOf: fixture.htmlURL, encoding: .utf8)

        // 期待値：ディスクと WebView 置換要求が取り消し前の同期スナップショットになる
        #expect(redoDiskHTML == "<!doctype html>\n<html><body>second</body></html>")
        #expect(store.documentReplacementRequest?.html == "<!doctype html>\n<html><body>second</body></html>")
        #expect(store.canRedo == false)
    }

    /// 論理名（日本語）: 外部HTML変更同期テスト
    /// 概要: ディスク上の HTML が外部変更された場合に WebView 置換要求へ変換されることを検証します。
    @Test("外部HTML変更を置換要求へ同期する")
    func testRefreshSelectedPageFromDiskCreatesReplacementRequest() throws {
        // コンディション：一時プロジェクトを開き、外部プロセス相当で HTML を書き換える
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let externalHTML = "<!doctype html>\n<html><body><Title data-og-id=\"title\" data-og-type=\"text\">external</Title></body></html>"
        try externalHTML.write(to: fixture.htmlURL, atomically: true, encoding: .utf8)

        // 検証内容：外部変更同期を実行する
        store.refreshSelectedPageFromDiskIfChanged()

        // 期待値：ディスク上の HTML が WebView 置換要求として保持される
        #expect(store.documentReplacementRequest?.html == externalHTML)
        #expect(store.documentReplacementRequest?.pageURL == fixture.htmlURL)
        #expect(store.statusMessage.contains("外部変更を同期"))
    }

    /// 論理名（日本語）: 非選択ページ外部HTML変更同期テスト
    /// 概要: キャンバス上の非選択ページが外部変更された場合に WebView reload token が更新されることを検証します。
    @Test("非選択ページの外部HTML変更でreload tokenを更新する")
    func testRefreshNonSelectedPageFromDiskUpdatesReloadToken() throws {
        // コンディション：home と downloads を持つ一時プロジェクトを開く
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let downloadsURL = fixture.publicURL.appendingPathComponent("downloads.html")
        try "<!doctype html>\n<html><body>downloads initial</body></html>".write(
            to: downloadsURL,
            atomically: true,
            encoding: .utf8
        )
        try fixture.writeProject(
            pages: [
                OpenGraphitePage(
                    id: "home",
                    path: "index.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                ),
                OpenGraphitePage(
                    id: "downloads",
                    path: "downloads.html",
                    canvas: OpenGraphiteCanvas(x: 120, y: 0, width: 100, height: 100)
                )
            ]
        )
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let initialToken = store.reloadToken(for: downloadsURL)

        // 検証内容：非選択ページの HTML を外部プロセス相当で書き換える
        try "<!doctype html>\n<html><body>downloads external</body></html>".write(
            to: downloadsURL,
            atomically: true,
            encoding: .utf8
        )
        store.refreshPageFromDiskIfChanged(at: downloadsURL)

        // 期待値：選択中ページの置換要求ではなく、非選択 WebView 用 reload token が更新される
        #expect(store.selectedPageID == "home")
        #expect(store.documentReplacementRequest == nil)
        #expect(store.reloadToken(for: downloadsURL) == initialToken + 1)
        #expect(store.statusMessage.contains("表示へ同期"))
    }

    /// 論理名（日本語）: 依存ファイル外部変更同期テスト
    /// 概要: CSS や component master の変更時に全 WebView の reload token が更新されることを検証します。
    @Test("依存ファイル変更で全pageのreload tokenを更新する")
    func testRefreshProjectDependenciesUpdatesAllReloadTokens() throws {
        // Given: 複数 page と component canvas を持つ一時プロジェクトを開く
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let downloadsURL = fixture.publicURL.appendingPathComponent("downloads.html")
        let componentDirectory = fixture.publicURL.appendingPathComponent("_components")
        let componentURL = componentDirectory.appendingPathComponent("design-system.html")
        try FileManager.default.createDirectory(at: componentDirectory, withIntermediateDirectories: true)
        try "<!doctype html>\n<html><body>downloads</body></html>".write(
            to: downloadsURL,
            atomically: true,
            encoding: .utf8
        )
        try "<!doctype html>\n<html><body>component</body></html>".write(
            to: componentURL,
            atomically: true,
            encoding: .utf8
        )
        let project = OpenGraphiteProject(
            version: "1",
            name: "History Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            pages: [
                OpenGraphitePage(
                    id: "home",
                    path: "index.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                ),
                OpenGraphitePage(
                    id: "downloads",
                    path: "downloads.html",
                    canvas: OpenGraphiteCanvas(x: 120, y: 0, width: 100, height: 100)
                )
            ],
            components: [
                OpenGraphitePage(
                    id: "design-system",
                    path: "_components/design-system.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 140, width: 100, height: 100)
                )
            ]
        )
        try JSONEncoder().encode(project).write(to: fixture.projectURL)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let initialHomeToken = store.reloadToken(for: fixture.htmlURL)
        let initialDownloadsToken = store.reloadToken(for: downloadsURL)
        let initialComponentToken = store.reloadToken(for: componentURL)

        // When: CSS / component などの依存ファイル変更を同期する
        store.refreshProjectDependenciesFromDisk()

        // Then: 選択中 page、非選択 page、component canvas の表示が再読込対象になる
        #expect(store.reloadToken(for: fixture.htmlURL) == initialHomeToken + 1)
        #expect(store.reloadToken(for: downloadsURL) == initialDownloadsToken + 1)
        #expect(store.reloadToken(for: componentURL) == initialComponentToken + 1)
        #expect(store.statusMessage == "CSS / Components の外部変更を表示へ同期しました。")
    }

    /// 論理名（日本語）: 未適用編集との競合テスト
    /// 概要: 未適用 mutation がある場合に外部 HTML 変更で WebView を破壊的に置換しないことを検証します。
    @Test("未適用編集がある場合は外部HTML変更同期を保留する")
    func testRefreshSelectedPageFromDiskDefersWhenMutationIsPending() throws {
        // コンディション：未適用 CSS mutation を持つストアで外部変更を発生させる
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        store.ingestNodePayload([
            [
                "id": "title",
                "tagName": "title",
                "type": "text",
                "cssVariables": ["--og-gap": "8px"],
                "depth": 0
            ]
        ])
        store.selectNode(id: "title")
        store.updateCSSVariable(key: "--og-gap", value: "16px")
        try "<!doctype html>\n<html><body>external</body></html>".write(
            to: fixture.htmlURL,
            atomically: true,
            encoding: .utf8
        )

        // 検証内容：外部変更同期を実行する
        store.refreshSelectedPageFromDiskIfChanged()

        // 期待値：未適用 mutation が優先され、置換要求は作られない
        #expect(store.documentReplacementRequest == nil)
        #expect(store.cssMutation?.value == "16px")
        #expect(store.statusMessage.contains("自動同期を保留"))
    }

    /// 論理名（日本語）: 外部プロジェクト変更同期テスト
    /// 概要: ディスク上の `.ogp` が外部変更された場合にページ一覧とキャンバス配置が再読み込みされることを検証します。
    @Test("外部ogp変更をページ一覧と配置へ同期する")
    func testRefreshProjectManifestReloadsPagesAndCanvas() throws {
        // コンディション：一時プロジェクトを開き、外部プロセス相当で `.ogp` にページを追加する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        let downloadsURL = fixture.publicURL.appendingPathComponent("downloads.html")
        try "<!doctype html>\n<html><body>downloads</body></html>".write(
            to: downloadsURL,
            atomically: true,
            encoding: .utf8
        )
        let updatedProject = OpenGraphiteProject(
            version: "1",
            name: "History Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            pages: [
                OpenGraphitePage(
                    id: "home",
                    path: "index.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                ),
                OpenGraphitePage(
                    id: "downloads",
                    path: "downloads.html",
                    canvas: OpenGraphiteCanvas(x: 1520, y: 0, width: 1440, height: 1200)
                )
            ]
        )
        let data = try JSONEncoder().encode(updatedProject)
        try data.write(to: fixture.projectURL)

        // 検証内容：外部 `.ogp` 変更同期を実行する
        store.refreshProjectManifestFromDiskIfChanged()

        // 期待値：追加ページと canvas 配置がストアへ反映される
        #expect(store.loadedProject?.project.allPages.map(\.id) == ["home", "downloads"])
        #expect(store.loadedProject?.project.allPages[1].canvas.x == 1520)
        #expect(store.selectedPageID == "home")
        #expect(store.statusMessage.contains(".ogp 外部変更を同期"))
    }

    /// 論理名（日本語）: Chapter選択テスト
    /// 概要: Chapter を切り替えると Pages と選択ページが選択 Chapter 内へ切り替わることを検証します。
    @Test("Chapter選択で表示対象ページ群を切り替える")
    func testSelectChapterSwitchesVisiblePages() throws {
        // コンディション：2つの Chapter を持つ一時プロジェクトを用意する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let docsURL = fixture.publicURL.appendingPathComponent("docs.html")
        try "<!doctype html>\n<html><body>docs</body></html>".write(
            to: docsURL,
            atomically: true,
            encoding: .utf8
        )
        let project = OpenGraphiteProject(
            version: "1",
            name: "History Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            chapters: [
                OpenGraphiteChapter(
                    id: "main",
                    title: "Main",
                    pages: [
                        OpenGraphitePage(
                            id: "home",
                            path: "index.html",
                            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                        )
                    ]
                ),
                OpenGraphiteChapter(
                    id: "docs",
                    title: "Docs",
                    pages: [
                        OpenGraphitePage(
                            id: "docs-home",
                            path: "docs.html",
                            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                        )
                    ]
                )
            ]
        )
        let data = try JSONEncoder().encode(project)
        try data.write(to: fixture.projectURL)
        let store = EditorStore()

        // 検証内容：プロジェクトを開き、docs Chapter を内部 ID で選択する
        store.openProject(at: fixture.projectURL)
        let docsChapterInternalID = try #require(store.loadedProject?.project.chapters[1].internalID)
        store.selectChapter(internalID: docsChapterInternalID)

        // 期待値：表示対象 Pages と選択ページが docs Chapter 内へ切り替わる
        #expect(store.selectedChapterID == "docs")
        #expect(store.selectedChapterPages.map(\.id) == ["docs-home"])
        #expect(store.selectedPageID == "docs-home")
        #expect(store.selectedPageURL == docsURL)
    }

    /// 論理名（日本語）: 複合ノード参照ID生成テスト
    /// 概要: Chapter と page の内部 ID を含む agent 向け node 参照 ID と pasteboard payload を生成できることを確認します。
    @Test("Chapter/Page内部IDを含むnode参照IDを生成する")
    func testNodeReferenceIDUsesInternalIDs() throws {
        // コンディション：Chapter 跨ぎで同じ page ID を持つ一時プロジェクトを用意する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let docsURL = fixture.publicURL.appendingPathComponent("docs.html")
        try "<!doctype html>\n<html><body>docs</body></html>".write(
            to: docsURL,
            atomically: true,
            encoding: .utf8
        )
        let project = OpenGraphiteProject(
            version: "1",
            name: "History Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            chapters: [
                OpenGraphiteChapter(
                    id: "main",
                    title: "Main",
                    pages: [
                        OpenGraphitePage(
                            id: "home",
                            path: "index.html",
                            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                        )
                    ]
                ),
                OpenGraphiteChapter(
                    id: "docs",
                    title: "Docs",
                    pages: [
                        OpenGraphitePage(
                            id: "home",
                            path: "docs.html",
                            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                        )
                    ]
                )
            ]
        )
        let data = try JSONEncoder().encode(project)
        try data.write(to: fixture.projectURL)
        let store = EditorStore()

        // 検証内容：docs Chapter を内部 ID で選択し、node 参照 payload を生成する
        store.openProject(at: fixture.projectURL)
        let docsChapterInternalID = try #require(store.loadedProject?.project.chapters[1].internalID)
        store.selectChapter(internalID: docsChapterInternalID)
        let referenceID = store.nodeReferenceID(forNodeID: "hero", nodeInternalID: "node-opaque")
        let payload = try #require(store.nodeReferencePasteboardPayload(
            forNodeID: "hero",
            nodeInternalID: "node-opaque",
            html: "<Hero></Hero>"
        ))

        // 期待値：複合参照 ID は Chapter 内部 ID、page 内部 ID、node 内部 ID を含む
        #expect(store.selectedPageURL == docsURL)
        #expect(referenceID == "ogref:node:\(docsChapterInternalID):\(store.selectedPage?.internalID ?? ""):node-opaque")
        #expect(payload["referenceID"] as? String == referenceID)
        #expect(payload["nodeID"] as? String == "hero")
        #expect(payload["nodeInternalID"] as? String == "node-opaque")
        #expect(payload["chapterIndex"] as? Int == 1)
        #expect(payload["pageIndex"] as? Int == 0)
        #expect(payload["html"] as? String == "<Hero></Hero>")
    }

    /// 論理名（日本語）: コンポーネント継承元解決テスト
    /// 概要: 選択中 instance の継承元 master を Inspector 用情報へ解決し、component canvas へ移動できることを確認します。
    @Test("instance選択から継承元componentへ移動できる")
    func testComponentSourceResolutionAndReveal() throws {
        // コンディション：component master HTML と、その instance を持つ一時プロジェクトを用意する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let componentDirectory = fixture.publicURL.appendingPathComponent("_components")
        let componentURL = componentDirectory.appendingPathComponent("design-system.html")
        try FileManager.default.createDirectory(at: componentDirectory, withIntermediateDirectories: true)
        try """
        <!doctype html>
        <html><body>
        <FeatureCard data-og-id="feature-card-master" data-og-type="frame" data-og-component="feature-card" data-og-component-kind="master"></FeatureCard>
        </body></html>
        """.write(to: componentURL, atomically: true, encoding: .utf8)
        let project = OpenGraphiteProject(
            version: "1",
            name: "History Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            pages: [
                OpenGraphitePage(
                    id: "home",
                    path: "index.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                )
            ],
            components: [
                OpenGraphitePage(
                    id: "design-system",
                    path: "_components/design-system.html",
                    canvas: OpenGraphiteCanvas(name: "Desktop", x: 1120, y: 0, width: 1180, height: 1900)
                )
            ]
        )
        try JSONEncoder().encode(project).write(to: fixture.projectURL)
        let store = EditorStore()
        store.openProject(at: fixture.projectURL)
        store.ingestNodePayload([
            [
                "id": "home-card-title",
                "tagName": "featurecardtitle",
                "type": "text",
                "sourceComponentID": "feature-card",
                "sourceInstanceID": "home-card",
                "depth": 1
            ]
        ])
        store.selectNode(id: "home-card-title")

        // 検証内容：選択ノードの継承元を解決し、Inspector の移動ボタン相当の処理を実行する
        let source = try #require(store.selectedComponentSource)
        store.revealComponentSource(source)

        // 期待値：master の名称と場所が解決され、Components 側の master root が選択される
        #expect(source.componentID == "feature-card")
        #expect(source.masterNodeID == "feature-card-master")
        #expect(source.locationLabel == "Main / design-system")
        #expect(source.componentPagePath == "_components/design-system.html")
        #expect(source.canvasLabel == "1120, 0 · 1180 x 1900")
        #expect(store.selectedCanvasSegment == .components)
        #expect(store.selectedComponentPageID == "design-system")
        #expect(store.selectedNodeID == "feature-card-master")
        #expect(store.statusMessage == "feature-card の component master を表示しています。")
    }

    /// 論理名（日本語）: 階層参照ID生成テスト
    /// 概要: Chapter、page、component canvas が各階層で agent 向けの一意な参照 ID を生成できることを確認します。
    @Test("Chapter/Page/Componentの参照IDを階層ごとに生成する")
    func testHierarchyReferenceIDsUseInternalIDs() throws {
        // コンディション：Chapter、page、component が内部 ID 候補を共有する project を用意する
        let fixture = try EditorStoreHistoryFixture()
        defer { fixture.cleanUp() }
        let docsURL = fixture.publicURL.appendingPathComponent("docs.html")
        let componentURL = fixture.publicURL.appendingPathComponent("card.html")
        try "<!doctype html>\n<html><body>docs</body></html>".write(
            to: docsURL,
            atomically: true,
            encoding: .utf8
        )
        try "<!doctype html>\n<html><body>card</body></html>".write(
            to: componentURL,
            atomically: true,
            encoding: .utf8
        )
        let project = OpenGraphiteProject(
            version: "1",
            name: "History Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            chapters: [
                OpenGraphiteChapter(
                    id: "main",
                    internalID: "opaque",
                    title: "Main",
                    pages: [
                        OpenGraphitePage(
                            id: "home",
                            internalID: "opaque",
                            path: "index.html",
                            canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                        )
                    ]
                ),
                OpenGraphiteChapter(
                    id: "docs",
                    internalID: "opaque",
                    title: "Docs",
                    pages: [
                        OpenGraphitePage(
                            id: "home",
                            internalID: "opaque",
                            path: "docs.html",
                            canvas: OpenGraphiteCanvas(x: 120, y: 0, width: 100, height: 100)
                        )
                    ]
                )
            ],
            components: [
                OpenGraphitePage(
                    id: "card",
                    internalID: "opaque",
                    path: "card.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 320, height: 240)
                )
            ]
        )
        let data = try JSONEncoder().encode(project)
        try data.write(to: fixture.projectURL)
        let store = EditorStore()

        // 検証内容：読み込み後の正規化済み内部 ID から階層参照 ID を生成する
        store.openProject(at: fixture.projectURL)
        let loadedProject = try #require(store.loadedProject?.project)
        let docsChapter = loadedProject.chapters[1]
        let docsPage = try #require(docsChapter.pages.first)
        let componentCollection = try #require(loadedProject.collections.first)
        let componentPage = try #require(loadedProject.components.first)
        store.selectChapter(internalID: docsChapter.internalID)
        let docsPageReferenceID = store.selectedPageReferenceID()
        store.selectComponentPage(internalID: componentPage.internalID)
        let componentReferenceID = store.selectedPageReferenceID()
        let hierarchyInternalIDs = loadedProject.chapters.map(\.internalID)
            + loadedProject.chapters.flatMap(\.pages).map(\.internalID)
            + loadedProject.collections.map(\.internalID)
            + loadedProject.components.map(\.internalID)

        // 期待値：内部 ID は manifest 階層全体で一意になり、page は Chapter を含む複合参照になる
        #expect(Set(hierarchyInternalIDs).count == hierarchyInternalIDs.count)
        #expect(store.chapterReferenceID(for: docsChapter) == "ogref:chapter:\(docsChapter.internalID)")
        #expect(docsPageReferenceID == "ogref:page:\(docsChapter.internalID):\(docsPage.internalID)")
        #expect(componentReferenceID == "ogref:component:\(componentCollection.internalID):\(componentPage.internalID)")
    }
}

/// 論理名（日本語）: エディターストア履歴テストfixture
/// 概要: 一時ディレクトリに `.ogp` と HTML を作成し、同期履歴テスト用のプロジェクトを提供します。
private struct EditorStoreHistoryFixture {
    let rootURL: URL
    let publicURL: URL
    let projectURL: URL
    let htmlURL: URL

    /// 論理名（日本語）: エディターストア履歴fixture初期化関数
    /// 処理概要: 一時ルート、public ディレクトリ、HTML、`.ogp` を作成します。
    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenGraphiteEditorStoreHistory-\(UUID().uuidString)")
        publicURL = rootURL.appendingPathComponent("public")
        projectURL = rootURL.appendingPathComponent("Project.ogp")
        htmlURL = publicURL.appendingPathComponent("index.html")

        try FileManager.default.createDirectory(at: publicURL, withIntermediateDirectories: true)
        try "<!doctype html>\n<html><body>initial</body></html>".write(
            to: htmlURL,
            atomically: true,
            encoding: .utf8
        )

        let project = OpenGraphiteProject(
            version: "1",
            name: "History Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            pages: [
                OpenGraphitePage(
                    id: "home",
                    path: "index.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 100, height: 100)
                )
            ]
        )
        let data = try JSONEncoder().encode(project)
        try data.write(to: projectURL)
    }

    /// 論理名（日本語）: project fixture書き換え関数
    /// 処理概要: 指定ページ一覧を持つ `.ogp` を fixture の project URL へ保存します。
    ///
    /// - Parameter pages: 保存する page entry 一覧。
    func writeProject(pages: [OpenGraphitePage]) throws {
        let project = OpenGraphiteProject(
            version: "1",
            name: "History Fixture",
            repositoryRoot: nil,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            pages: pages
        )
        let data = try JSONEncoder().encode(project)
        try data.write(to: projectURL)
    }

    /// 論理名（日本語）: fixture削除関数
    /// 処理概要: テストで作成した一時ディレクトリを削除します。
    func cleanUp() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
