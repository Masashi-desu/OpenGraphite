import Foundation
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: プロジェクト作成器関連のテストスイート
/// 概要: 新規 `.ogp` と初期 HTML/CSS seed の生成、既存ファイル保護を確認します。
@Suite("プロジェクト作成器関連のテストスイート")
struct ProjectCreatorTests {
    /// 論理名（日本語）: 新規プロジェクトseed作成テスト
    /// 概要: 拡張子なし URL から `.ogp`、初期 HTML、companion CSS、CSS library を作成できることを検証します。
    @Test("新規ogpと初期HTML/CSSを作成できる")
    func testCreateProjectWritesManifestHTMLAndCSSSeed() throws {
        // コンディション：OpenGraphite.css seed と拡張子なしの作成先を用意する（Given）
        let fixture = try ProjectCreatorFixture()
        defer { fixture.cleanUp() }
        let creator = ProjectCreator(cssLibrarySourceURL: { fixture.cssSourceURL })

        // 検証内容：新規 project を作成する（When）
        let createdProjectURL = try creator.createProject(
            at: fixture.rootURL.appendingPathComponent("Created Project")
        )
        let loadedProject = try ProjectLoader().loadProject(at: createdProjectURL)
        let htmlURL = fixture.rootURL.appendingPathComponent("public/index.html")
        let companionCSSURL = fixture.rootURL.appendingPathComponent("public/index.css")
        let cssURL = fixture.rootURL.appendingPathComponent("CSS/OpenGraphite.css")
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let css = try String(contentsOf: cssURL, encoding: .utf8)

        // 期待値：既存 loader で開ける self-contained project seed が揃う（Then）
        #expect(createdProjectURL.lastPathComponent == "Created Project.ogp")
        #expect(loadedProject.project.name == "Created Project")
        #expect(loadedProject.project.htmlRoot == "public")
        #expect(loadedProject.project.cssLibrary == "CSS/OpenGraphite.css")
        #expect(loadedProject.project.chapters.count == 1)
        #expect(loadedProject.project.chapters[0].pages.count == 1)
        #expect(loadedProject.project.chapters[0].pages[0].id == "home")
        #expect(loadedProject.project.chapters[0].pages[0].path == "index.html")
        #expect(!loadedProject.project.chapters[0].pages[0].internalID.isEmpty)
        #expect(FileManager.default.fileExists(atPath: companionCSSURL.path))
        #expect(css == fixture.cssSeed)
        #expect(html.contains("<title>Created Project</title>"))
        #expect(html.contains(#"href="../CSS/OpenGraphite.css""#))
        #expect(html.contains(#"href="index.css""#))
        #expect(html.contains(#"data-og-id="home-root""#))
        #expect(html.contains(#"data-og-id="headline""#))
    }

    /// 論理名（日本語）: 既存public採用テスト
    /// 概要: 保存先に既存 `public` がある場合は seed を作成せず、HTML も自動登録しないことを検証します。
    @Test("既存publicがある場合はseedを作らずHTMLも自動登録しない")
    func testCreateProjectWithExistingPublicWritesEmptyManifestOnly() throws {
        // コンディション：既存 web project の public 配下に HTML と CSS がある（Given）
        let fixture = try ProjectCreatorFixture()
        defer { fixture.cleanUp() }
        let publicURL = fixture.rootURL.appendingPathComponent("public", isDirectory: true)
        let htmlURL = publicURL.appendingPathComponent("index.html")
        let companionCSSURL = publicURL.appendingPathComponent("index.css")
        try FileManager.default.createDirectory(at: publicURL, withIntermediateDirectories: true)
        try "<!doctype html><html><body>Existing</body></html>".write(
            to: htmlURL,
            atomically: true,
            encoding: .utf8
        )
        try "body { color: red; }\n".write(
            to: companionCSSURL,
            atomically: true,
            encoding: .utf8
        )
        let creator = ProjectCreator(cssLibrarySourceURL: { fixture.cssSourceURL })

        // 検証内容：既存 public と同じディレクトリへ `.ogp` を作成する（When）
        let createdProjectURL = try creator.createProject(
            at: fixture.rootURL.appendingPathComponent("Existing Web.ogp")
        )
        let loadedProject = try ProjectLoader().loadProject(at: createdProjectURL)

        // 期待値：既存ファイルは変更されず、HTML page entry も自動追加されない（Then）
        #expect(loadedProject.project.name == "Existing Web")
        #expect(loadedProject.project.chapters.count == 1)
        #expect(loadedProject.project.chapters[0].pages.isEmpty)
        #expect(loadedProject.project.allPages.isEmpty)
        #expect(try String(contentsOf: htmlURL, encoding: .utf8) == "<!doctype html><html><body>Existing</body></html>")
        #expect(try String(contentsOf: companionCSSURL, encoding: .utf8) == "body { color: red; }\n")
        #expect(!FileManager.default.fileExists(atPath: fixture.rootURL.appendingPathComponent("CSS/OpenGraphite.css").path))
    }

    /// 論理名（日本語）: 既存ogp保護テスト
    /// 概要: 作成先 `.ogp` が既に存在する場合に上書きしないことを検証します。
    @Test("既存ogpは上書きしない")
    func testCreateProjectRejectsExistingProjectFile() throws {
        // コンディション：既に存在する `.ogp` と CSS seed を用意する（Given）
        let fixture = try ProjectCreatorFixture()
        defer { fixture.cleanUp() }
        let projectURL = fixture.rootURL.appendingPathComponent("Existing.ogp")
        try "existing".write(to: projectURL, atomically: true, encoding: .utf8)
        let creator = ProjectCreator(cssLibrarySourceURL: { fixture.cssSourceURL })

        // 検証内容：同じ URL に新規 project を作成する（When）
        do {
            try creator.createProject(at: projectURL)
            Issue.record("既存 `.ogp` への作成が成功してはいけません。")
        } catch ProjectCreationError.projectAlreadyExists(let rejectedURL) {
            // 期待値：既存 `.ogp` が保護され、内容が保持される（Then）
            #expect(rejectedURL == projectURL.standardizedFileURL)
            #expect(try String(contentsOf: projectURL, encoding: .utf8) == "existing")
        } catch {
            Issue.record("想定外のエラーです: \(error)")
        }
    }
}

/// 論理名（日本語）: プロジェクト作成器テスト用フィクスチャ
/// 概要: 一時ディレクトリと OpenGraphite.css seed を生成し、各テストからファイルシステムを分離します。
///
/// プロパティ:
/// - `rootURL`: テスト専用の一時ルートディレクトリ。
/// - `cssSourceURL`: creator に渡す CSS seed URL。
/// - `cssSeed`: CSS seed の内容。
private final class ProjectCreatorFixture {
    let rootURL: URL
    let cssSourceURL: URL
    let cssSeed = "body { margin: 0; }\n"

    /// 論理名（日本語）: フィクスチャ初期化関数
    /// 処理概要: 一意な一時ディレクトリと CSS seed file を作成します。
    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenGraphiteProjectCreatorTests-\(UUID().uuidString)", isDirectory: true)
        let seedDirectoryURL = rootURL.appendingPathComponent("Seed", isDirectory: true)
        cssSourceURL = seedDirectoryURL.appendingPathComponent("OpenGraphite.css")
        try FileManager.default.createDirectory(at: seedDirectoryURL, withIntermediateDirectories: true)
        try cssSeed.write(to: cssSourceURL, atomically: true, encoding: .utf8)
    }

    /// 論理名（日本語）: fixture削除関数
    /// 処理概要: テストで作成した一時ディレクトリを削除します。
    func cleanUp() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
