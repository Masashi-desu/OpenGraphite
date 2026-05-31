import Foundation
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: サンプルプロジェクト解決テストスイート
/// 概要: Debug sample `.ogp` 優先、Application Support への seed 初回コピー、既存 sample 保護、bundle seed 欠落時のエラーを検証します。
@Suite("サンプルプロジェクト解決テストスイート")
struct SampleProjectLocatorTests {
    /// 論理名（日本語）: 環境変数sampleパス優先テスト
    /// 概要: `OPENGRAPHITE_SAMPLE_PROJECT_PATH` が有効な場合に、Application Support へコピーせず指定 sample `.ogp` を返すことを検証します。
    @Test("環境変数のsample ogpパスを優先する")
    func testUsesSampleProjectPathWhenEnvironmentIsAvailable() throws {
        // コンディション：端末上の sample `.ogp` と、失敗する seed installer を用意する
        let fixture = try SampleProjectLocatorFixture()
        defer { fixture.cleanUp() }
        try fixture.writeSampleTree(at: fixture.repositoryRootURL)
        let locator = fixture.makeLocator(
            environment: [
                SampleProjectLocator.sampleProjectPathEnvironmentKey: fixture.repositorySampleProjectURL.path
            ],
            bundleResourceRootURL: { nil }
        )

        // 検証内容：sample URL を解決する
        let resolvedURL = try locator.sampleProjectURL()

        // 期待値：環境変数で指定された sample `.ogp` が返り、Application Support にはコピーされない
        #expect(resolvedURL == fixture.repositorySampleProjectURL.standardizedFileURL)
        #expect(!FileManager.default.fileExists(atPath: fixture.installedSampleProjectURL.path))
    }

    /// 論理名（日本語）: 環境変数sample欠落エラーテスト
    /// 概要: `OPENGRAPHITE_SAMPLE_PROJECT_PATH` が存在しないファイルを指す場合に、Release fallback へ進まず明示エラーにすることを検証します。
    @Test("環境変数sample ogpパスが欠けている場合はエラーにする")
    func testThrowsWhenSampleProjectPathEnvironmentIsMissing() throws {
        // コンディション：存在しない sample `.ogp` パスと、有効な bundle seed を用意する
        let fixture = try SampleProjectLocatorFixture()
        defer { fixture.cleanUp() }
        try fixture.writeBundleSeed(indexHTML: "seed")
        let locator = fixture.makeLocator(
            environment: [
                SampleProjectLocator.sampleProjectPathEnvironmentKey: fixture.repositorySampleProjectURL.path
            ]
        )

        // 検証内容：sample URL 解決時のエラーを確認する
        do {
            _ = try locator.sampleProjectURL()
            Issue.record("存在しない環境変数 sample path で成功してはいけません。")
        } catch let error as SampleProjectLocationError {
            // 期待値：Debug 設定ミスとして missingEnvironmentSampleProject が返る
            #expect(error == .missingEnvironmentSampleProject(fixture.repositorySampleProjectURL.standardizedFileURL))
            #expect(!FileManager.default.fileExists(atPath: fixture.installedSampleProjectURL.path))
        }
    }

    /// 論理名（日本語）: bundle seed 初回コピーテスト
    /// 概要: 環境変数がない場合に、bundle seed を Application Support へコピーし、その `.ogp` が HTML/CSS を解決できることを検証します。
    @Test("環境変数がない場合はbundle seedをApplication Supportへ初回コピーする")
    func testInstallsBundleSeedIntoApplicationSupportWhenEnvironmentIsUnavailable() throws {
        // コンディション：bundle seed だけが存在する状態を用意する
        let fixture = try SampleProjectLocatorFixture()
        defer { fixture.cleanUp() }
        try fixture.writeBundleSeed(indexHTML: "seed-html")
        let locator = fixture.makeLocator(environment: [:])

        // 検証内容：sample URL を解決して ProjectLoader で読み込む
        let resolvedURL = try locator.sampleProjectURL()
        let loadedProject = try ProjectLoader().loadProject(at: resolvedURL)
        let html = try String(contentsOf: loadedProject.htmlURL(for: loadedProject.project.pages[0]), encoding: .utf8)

        // 期待値：Application Support の編集用コピーが返り、`.ogp` の相対パスで HTML/CSS が解決される
        #expect(resolvedURL == fixture.installedSampleProjectURL.standardizedFileURL)
        #expect(html == "seed-html")
        #expect(FileManager.default.fileExists(atPath: loadedProject.cssURL.path))
    }

    /// 論理名（日本語）: 既存Application Support sample保護テスト
    /// 概要: Application Support 側に sample `.ogp` がある場合に、bundle seed で上書きしないことを検証します。
    @Test("既存のApplication Support sampleは上書きしない")
    func testDoesNotOverwriteExistingInstalledSample() throws {
        // コンディション：既存編集用 sample と、内容が異なる bundle seed を用意する
        let fixture = try SampleProjectLocatorFixture()
        defer { fixture.cleanUp() }
        try fixture.writeBundleSeed(indexHTML: "seed-html")
        try fixture.writeSampleTree(at: fixture.installedSampleRootURL, indexHTML: "user-html")
        let locator = fixture.makeLocator(environment: [:])

        // 検証内容：sample URL を解決し、既存 HTML を読む
        let resolvedURL = try locator.sampleProjectURL()
        let loadedProject = try ProjectLoader().loadProject(at: resolvedURL)
        let html = try String(contentsOf: loadedProject.htmlURL(for: loadedProject.project.pages[0]), encoding: .utf8)

        // 期待値：既存 Application Support sample が返り、ユーザー編集相当の内容が保持される
        #expect(resolvedURL == fixture.installedSampleProjectURL.standardizedFileURL)
        #expect(html == "user-html")
    }

    /// 論理名（日本語）: bundle seed 欠落エラーテスト
    /// 概要: bundle seed に必要なディレクトリが存在しない場合に、明確なエラーを返すことを検証します。
    @Test("bundle seedが欠けている場合は明確なエラーにする")
    func testThrowsWhenBundleSeedIsMissing() throws {
        // コンディション：環境変数も bundle seed も存在しない状態を用意する
        let fixture = try SampleProjectLocatorFixture()
        defer { fixture.cleanUp() }
        let locator = fixture.makeLocator(environment: [:])

        // 検証内容：sample URL 解決時のエラーを確認する
        do {
            _ = try locator.sampleProjectURL()
            Issue.record("bundle seed 欠落時に成功してはいけません。")
        } catch let error as SampleProjectLocationError {
            // 期待値：不足している seed resource 名がエラーに含まれる
            guard case .missingBundleSeedResource(let name, _) = error else {
                Issue.record("想定外のエラーです: \(error)")
                return
            }
            #expect(name == "SampleProject")
        }
    }
}

/// 論理名（日本語）: サンプルプロジェクト解決テストフィクスチャ
/// 概要: locator 用の一時 root、bundle seed、Application Support 相当のディレクトリを作成します。
private final class SampleProjectLocatorFixture {
    let rootURL: URL
    let repositoryRootURL: URL
    let bundleResourceRootURL: URL
    let applicationSupportRootURL: URL
    let installedSampleRootURL: URL

    var repositorySampleProjectURL: URL {
        repositoryRootURL
            .appendingPathComponent("SampleProject")
            .appendingPathComponent("OpenGraphiteSample.ogp")
            .standardizedFileURL
    }

    var installedSampleProjectURL: URL {
        installedSampleRootURL
            .appendingPathComponent("SampleProject")
            .appendingPathComponent("OpenGraphiteSample.ogp")
            .standardizedFileURL
    }

    /// 論理名（日本語）: フィクスチャ初期化関数
    /// 処理概要: 一時 root と各種 seed/source 用ディレクトリ URL を構成します。
    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenGraphiteSampleProjectLocator-\(UUID().uuidString)")
        repositoryRootURL = rootURL.appendingPathComponent("Repository", isDirectory: true)
        bundleResourceRootURL = rootURL.appendingPathComponent("BundleResources", isDirectory: true)
        applicationSupportRootURL = rootURL
            .appendingPathComponent("ApplicationSupport", isDirectory: true)
            .appendingPathComponent("OpenGraphite", isDirectory: true)
        installedSampleRootURL = applicationSupportRootURL
            .appendingPathComponent("Samples", isDirectory: true)
            .appendingPathComponent("OpenGraphiteSample", isDirectory: true)

        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    /// 論理名（日本語）: locator生成関数
    /// 処理概要: テスト用の環境変数、bundle root、Application Support root を注入した locator を返します。
    ///
    /// - Parameters:
    ///   - environment: locator に渡す環境変数。
    ///   - bundleResourceRootURL: bundle resource root provider。
    /// - Returns: テスト用 `SampleProjectLocator`。
    func makeLocator(
        environment: [String: String],
        bundleResourceRootURL: @escaping () -> URL? = { nil }
    ) -> SampleProjectLocator {
        let installer = SampleSeedInstaller(
            bundleResourceRootURL: {
                bundleResourceRootURL() ?? self.bundleResourceRootURL
            },
            applicationSupportRootURL: {
                self.applicationSupportRootURL
            }
        )
        return SampleProjectLocator(environment: environment, seedInstaller: installer)
    }

    /// 論理名（日本語）: bundle seed作成関数
    /// 処理概要: bundle resources 相当の root に sample tree を作成します。
    ///
    /// - Parameter indexHTML: `public/index.html` に書き込む内容。
    func writeBundleSeed(indexHTML: String) throws {
        try writeSampleTree(at: bundleResourceRootURL, indexHTML: indexHTML)
    }

    /// 論理名（日本語）: sample tree作成関数
    /// 処理概要: 指定 root 配下に `.ogp`、HTML、CSS を `.ogp` の相対パスが成立する形で作成します。
    ///
    /// - Parameters:
    ///   - rootURL: sample tree を作成する root URL。
    ///   - indexHTML: `public/index.html` に書き込む内容。
    func writeSampleTree(at rootURL: URL, indexHTML: String = "index-html") throws {
        let sampleProjectDirectoryURL = rootURL.appendingPathComponent("SampleProject", isDirectory: true)
        let publicDirectoryURL = rootURL.appendingPathComponent("public", isDirectory: true)
        let cssDirectoryURL = rootURL.appendingPathComponent("CSS", isDirectory: true)

        try FileManager.default.createDirectory(at: sampleProjectDirectoryURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: publicDirectoryURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cssDirectoryURL, withIntermediateDirectories: true)

        try Self.sampleProjectJSON.write(
            to: sampleProjectDirectoryURL.appendingPathComponent("OpenGraphiteSample.ogp"),
            atomically: true,
            encoding: .utf8
        )
        try indexHTML.write(
            to: publicDirectoryURL.appendingPathComponent("index.html"),
            atomically: true,
            encoding: .utf8
        )
        try "body { margin: 0; }".write(
            to: cssDirectoryURL.appendingPathComponent("OpenGraphite.css"),
            atomically: true,
            encoding: .utf8
        )
    }

    /// 論理名（日本語）: フィクスチャ削除関数
    /// 処理概要: テスト用一時ディレクトリを削除します。
    func cleanUp() {
        try? FileManager.default.removeItem(at: rootURL)
    }

    private static let sampleProjectJSON = """
    {
      "cssLibrary": "CSS/OpenGraphite.css",
      "htmlRoot": "public",
      "name": "OpenGraphite Sample",
      "pages": [
        {
          "canvas": {
            "height": 1200,
            "width": 1440,
            "x": 0,
            "y": 0
          },
          "id": "home",
          "path": "index.html"
        }
      ],
      "repositoryRoot": "..",
      "version": "0.1.0"
    }
    """
}
