import Foundation
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: プロジェクトローダー関連のテストスイート
/// 概要: .ogp の読み込み、相対ルート解決、エラー処理を確認します。
@Suite("プロジェクトローダー関連のテストスイート")
struct ProjectLoaderTests {
    /// 論理名（日本語）: 相対リポジトリルート解決テスト
    /// 概要: .ogp に repositoryRoot がある場合、HTML 参照先が正しく解決されることを検証します。
    @Test("相対repositoryRootを解決してHTMLを読み込める")
    func testLoadProjectResolvesRelativeRepositoryRoot() throws {
        // コンディション：SampleProject から一階層上を repositoryRoot とする .ogp と HTML を用意する
        let fixture = try ProjectLoaderFixture()
        let repositoryURL = fixture.rootURL.appendingPathComponent("Repository")
        let projectDirectory = repositoryURL.appendingPathComponent("SampleProject")
        let publicDirectory = repositoryURL.appendingPathComponent("public")
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: publicDirectory, withIntermediateDirectories: true)
        try "<!doctype html><html><body></body></html>".write(
            to: publicDirectory.appendingPathComponent("index.html"),
            atomically: true,
            encoding: .utf8
        )
        let projectURL = projectDirectory.appendingPathComponent("OpenGraphiteSample.ogp")
        try fixture.writeProject(
            repositoryRoot: "..",
            pages: [
                OpenGraphitePage(
                    id: "home",
                    path: "index.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 1440, height: 1200)
                )
            ],
            to: projectURL
        )

        // 検証内容：プロジェクトを読み込む
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)

        // 期待値：rootURL と HTML URL がリポジトリルート基準で解決される
        #expect(loadedProject.rootURL == repositoryURL.standardizedFileURL)
        #expect(loadedProject.htmlURL(for: loadedProject.project.allPages[0]) == publicDirectory.appendingPathComponent("index.html"))
    }

    /// 論理名（日本語）: 旧pages形式プロジェクト読み込みテスト
    /// 概要: Chapter 導入前の top-level pages 形式を既定 Chapter として読み込めることを検証します。
    @Test("旧top-level pages形式を既定Chapterとして読み込める")
    func testLoadProjectAcceptsLegacyTopLevelPages() throws {
        // コンディション：旧形式の pages を持つ .ogp と HTML を用意する
        let fixture = try ProjectLoaderFixture()
        let publicDirectory = fixture.rootURL.appendingPathComponent("public")
        try FileManager.default.createDirectory(at: publicDirectory, withIntermediateDirectories: true)
        try "<!doctype html><html><body></body></html>".write(
            to: publicDirectory.appendingPathComponent("index.html"),
            atomically: true,
            encoding: .utf8
        )
        let projectURL = fixture.rootURL.appendingPathComponent("Legacy.ogp")
        try """
        {
          "version": "0.1.0",
          "name": "Legacy",
          "htmlRoot": "public",
          "cssLibrary": "CSS/OpenGraphite.css",
          "pages": [
            {
              "id": "home",
              "path": "index.html",
              "canvas": { "name": "", "x": 0, "y": 0, "width": 1440, "height": 1200 }
            }
          ]
        }
        """.write(to: projectURL, atomically: true, encoding: .utf8)

        // 検証内容：プロジェクトを読み込む
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)

        // 期待値：旧 pages が既定 Chapter 配下へ正規化される
        #expect(loadedProject.project.chapters.map(\.id) == [OpenGraphiteChapter.defaultID])
        #expect(loadedProject.project.chapters[0].pages.map(\.id) == ["home"])
        #expect(loadedProject.project.components.isEmpty)
    }

    /// 論理名（日本語）: 内部ID補完テスト
    /// 概要: 旧形式 `.ogp` に内部 ID がない場合、Chapter と page に一意な内部 ID が補完されることを検証します。
    @Test("旧形式projectにChapter/Page内部IDを補完する")
    func testLoadProjectNormalizesInternalIDs() throws {
        // コンディション：Chapter ID と page ID が重複する旧形式 `.ogp` と HTML を用意する
        let fixture = try ProjectLoaderFixture()
        let publicDirectory = fixture.rootURL.appendingPathComponent("public")
        try FileManager.default.createDirectory(at: publicDirectory, withIntermediateDirectories: true)
        try "<!doctype html><html><body>home</body></html>".write(
            to: publicDirectory.appendingPathComponent("index.html"),
            atomically: true,
            encoding: .utf8
        )
        try "<!doctype html><html><body>docs</body></html>".write(
            to: publicDirectory.appendingPathComponent("docs.html"),
            atomically: true,
            encoding: .utf8
        )
        let projectURL = fixture.rootURL.appendingPathComponent("DuplicateIDs.ogp")
        try """
        {
          "version": "0.1.0",
          "name": "Duplicate IDs",
          "htmlRoot": "public",
          "cssLibrary": "CSS/OpenGraphite.css",
          "chapters": [
            {
              "id": "main",
              "pages": [
                {
                  "id": "home",
                  "path": "index.html",
                  "canvas": { "name": "", "x": 0, "y": 0, "width": 1440, "height": 1200 }
                }
              ]
            },
            {
              "id": "main",
              "pages": [
                {
                  "id": "home",
                  "path": "docs.html",
                  "canvas": { "name": "", "x": 1520, "y": 0, "width": 1440, "height": 1200 }
                }
              ]
            }
          ]
        }
        """.write(to: projectURL, atomically: true, encoding: .utf8)

        // 検証内容：プロジェクトを読み込む
        let loadedProject = try ProjectLoader().loadProject(at: projectURL)

        // 期待値：Chapter と page の内部 ID が意味付き slug ではない値で一意に補完される
        let chapterInternalIDs = loadedProject.project.chapters.map(\.internalID)
        let pageInternalIDs = loadedProject.project.chapters.flatMap(\.pages).map(\.internalID)
        #expect(Set(chapterInternalIDs).count == 2)
        #expect(Set(pageInternalIDs).count == 2)
        #expect(!chapterInternalIDs.contains("chapter-main"))
        #expect(!pageInternalIDs.contains("page-home"))
    }

    /// 論理名（日本語）: ページ未定義エラーテスト
    /// 概要: pages が空の .ogp を読み込んだときに missingPages が発生することを検証します。
    @Test("pagesが空ならmissingPagesを返す")
    func testLoadProjectThrowsMissingPages() throws {
        // コンディション：pages が空の .ogp を用意する
        let fixture = try ProjectLoaderFixture()
        let projectURL = fixture.rootURL.appendingPathComponent("Empty.ogp")
        try fixture.writeProject(repositoryRoot: nil, pages: [], to: projectURL)

        // 検証内容：プロジェクト読み込み時の例外を確認する
        do {
            _ = try ProjectLoader().loadProject(at: projectURL)
            Issue.record("missingPages が発生する必要があります。")
        } catch ProjectLoadError.missingPages {
            // 期待値：missingPages が発生する
            #expect(true)
        } catch {
            Issue.record("想定外のエラーです: \(error)")
        }
    }

    /// 論理名（日本語）: HTML未検出エラーテスト
    /// 概要: pages は存在するが対象 HTML がない場合に missingHTML が発生することを検証します。
    @Test("HTMLがなければmissingHTMLを返す")
    func testLoadProjectThrowsMissingHTML() throws {
        // コンディション：HTML ファイルが存在しない .ogp を用意する
        let fixture = try ProjectLoaderFixture()
        let projectURL = fixture.rootURL.appendingPathComponent("MissingHTML.ogp")
        try fixture.writeProject(
            repositoryRoot: nil,
            pages: [
                OpenGraphitePage(
                    id: "home",
                    path: "missing.html",
                    canvas: OpenGraphiteCanvas(x: 0, y: 0, width: 1440, height: 1200)
                )
            ],
            to: projectURL
        )

        // 検証内容：プロジェクト読み込み時の例外を確認する
        do {
            _ = try ProjectLoader().loadProject(at: projectURL)
            Issue.record("missingHTML が発生する必要があります。")
        } catch ProjectLoadError.missingHTML(let url) {
            // 期待値：missingHTML が不足している HTML の URL を保持する
            #expect(url.lastPathComponent == "missing.html")
        } catch {
            Issue.record("想定外のエラーです: \(error)")
        }
    }
}

/// 論理名（日本語）: プロジェクトローダーテスト用フィクスチャ
/// 概要: 一時ディレクトリと .ogp JSON を生成し、各テストからファイルシステムを分離します。
///
/// プロパティ:
/// - `rootURL`: テスト専用の一時ルートディレクトリ。
private final class ProjectLoaderFixture {
    let rootURL: URL

    /// 論理名（日本語）: フィクスチャ初期化関数
    /// 処理概要: 一意な一時ディレクトリを作成します。
    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenGraphiteTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: rootURL)
    }

    /// 論理名（日本語）: プロジェクトJSON書き込み関数
    /// 処理概要: 指定された pages と repositoryRoot を持つ .ogp ファイルを作成します。
    ///
    /// - Parameters:
    ///   - repositoryRoot: .ogp から見たリポジトリルート。省略時は未指定として書き込みます。
    ///   - pages: .ogp に含めるページ一覧。
    ///   - url: 書き込み先の .ogp URL。
    func writeProject(repositoryRoot: String?, pages: [OpenGraphitePage], to url: URL) throws {
        let project = OpenGraphiteProject(
            version: "0.1.0",
            name: "Fixture",
            repositoryRoot: repositoryRoot,
            htmlRoot: "public",
            cssLibrary: "CSS/OpenGraphite.css",
            pages: pages
        )
        let data = try JSONEncoder().encode(project)
        try data.write(to: url)
    }
}
