import Foundation

/// 論理名（日本語）: サンプルプロジェクト解決エラー
/// 概要: Debug sample path や bundle seed、Application Support コピーの解決に失敗した理由を表します。
///
/// 定義内容:
/// - `missingEnvironmentSampleProject`: 環境変数が指す sample `.ogp` が存在しない。
/// - `missingApplicationSupportDirectory`: Application Support ディレクトリを解決できない。
/// - `missingBundleSeedResource`: bundle seed に必要なリソースが存在しない。
/// - `missingInstalledSampleProject`: seed コピー後の sample `.ogp` が存在しない。
enum SampleProjectLocationError: LocalizedError, Equatable {
    case missingEnvironmentSampleProject(URL)
    case missingApplicationSupportDirectory
    case missingBundleSeedResource(name: String, url: URL)
    case missingInstalledSampleProject(URL)

    var errorDescription: String? {
        switch self {
        case .missingEnvironmentSampleProject(let url):
            return "Debug sample project が見つかりません: \(url.path)"
        case .missingApplicationSupportDirectory:
            return "Application Support ディレクトリを解決できません。"
        case .missingBundleSeedResource(let name, let url):
            return "bundle seed に必要な \(name) が見つかりません: \(url.path)"
        case .missingInstalledSampleProject(let url):
            return "sample seed コピー後の .ogp が見つかりません: \(url.path)"
        }
    }
}

/// 論理名（日本語）: サンプルseedインストーラー
/// 概要: アプリバンドル内の sample seed を Application Support 配下の編集用コピーへ初回展開します。
///
/// プロパティ:
/// - `bundleResourceRootURL`: `.app/Contents/Resources` を返す provider。
/// - `applicationSupportRootURL`: `Application Support/OpenGraphite` を返す provider。
/// - `fileManager`: seed の存在確認とコピーに使う FileManager。
struct SampleSeedInstaller {
    private static let seedDirectoryNames = ["SampleProject", "public", "CSS"]
    private static let sampleRelativePath = "Samples/OpenGraphiteSample"
    private static let projectRelativePath = "SampleProject/OpenGraphiteSample.ogp"

    private let bundleResourceRootURL: () -> URL?
    private let applicationSupportRootURL: () throws -> URL
    private let fileManager: FileManager

    /// 論理名（日本語）: サンプルseedインストーラー初期化関数
    /// 処理概要: bundle seed と Application Support の解決 provider を保持します。
    ///
    /// - Parameters:
    ///   - bundleResourceRootURL: `.app/Contents/Resources` を返す provider。
    ///   - applicationSupportRootURL: `Application Support/OpenGraphite` を返す provider。
    ///   - fileManager: ファイル操作に使う FileManager。
    init(
        bundleResourceRootURL: @escaping () -> URL? = { Bundle.main.resourceURL },
        applicationSupportRootURL: @escaping () throws -> URL = {
            guard let applicationSupportURL = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                throw SampleProjectLocationError.missingApplicationSupportDirectory
            }

            return applicationSupportURL.appendingPathComponent("OpenGraphite", isDirectory: true)
        },
        fileManager: FileManager = .default
    ) {
        self.bundleResourceRootURL = bundleResourceRootURL
        self.applicationSupportRootURL = applicationSupportRootURL
        self.fileManager = fileManager
    }

    /// 論理名（日本語）: インストール済みサンプルURL取得関数
    /// 処理概要: Application Support の sample `.ogp` を返し、未配置なら bundle seed から初回コピーします。
    ///
    /// - Returns: 編集用コピーとして開く sample `.ogp` URL。
    func installedSampleProjectURL() throws -> URL {
        let sampleRootURL = try installedSampleRootURL()
        let sampleProjectURL = sampleRootURL.appendingPathComponent(Self.projectRelativePath)

        if fileManager.fileExists(atPath: sampleProjectURL.path) {
            return sampleProjectURL
        }

        try installSeed(to: sampleRootURL)

        guard fileManager.fileExists(atPath: sampleProjectURL.path) else {
            throw SampleProjectLocationError.missingInstalledSampleProject(sampleProjectURL)
        }

        return sampleProjectURL
    }

    /// 論理名（日本語）: インストール先サンプルルート取得関数
    /// 処理概要: `Application Support/OpenGraphite/Samples/OpenGraphiteSample` の URL を返します。
    ///
    /// - Returns: sample seed のコピー先 root URL。
    private func installedSampleRootURL() throws -> URL {
        try applicationSupportRootURL()
            .appendingPathComponent(Self.sampleRelativePath, isDirectory: true)
            .standardizedFileURL
    }

    /// 論理名（日本語）: サンプルseed初回コピー関数
    /// 処理概要: bundle seed の `SampleProject`、`public`、`CSS` を一時ディレクトリへコピーしてから編集用 root へ配置します。
    ///
    /// - Parameter sampleRootURL: seed の最終コピー先 root URL。
    private func installSeed(to sampleRootURL: URL) throws {
        let bundleRootURL = try bundleRootURLWithRequiredResources()
        let samplesDirectoryURL = sampleRootURL.deletingLastPathComponent()
        let temporaryRootURL = samplesDirectoryURL
            .appendingPathComponent(".OpenGraphiteSample-\(UUID().uuidString)", isDirectory: true)

        try fileManager.createDirectory(
            at: samplesDirectoryURL,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: temporaryRootURL,
            withIntermediateDirectories: true
        )

        do {
            for directoryName in Self.seedDirectoryNames {
                try fileManager.copyItem(
                    at: bundleRootURL.appendingPathComponent(directoryName, isDirectory: true),
                    to: temporaryRootURL.appendingPathComponent(directoryName, isDirectory: true)
                )
            }

            let installedProjectURL = sampleRootURL.appendingPathComponent(Self.projectRelativePath)
            if fileManager.fileExists(atPath: installedProjectURL.path) {
                try? fileManager.removeItem(at: temporaryRootURL)
                return
            }

            try fileManager.moveItem(at: temporaryRootURL, to: sampleRootURL)
        } catch {
            try? fileManager.removeItem(at: temporaryRootURL)
            throw error
        }
    }

    /// 論理名（日本語）: bundle seed ルート検証関数
    /// 処理概要: bundle resource root と seed に必要なディレクトリの存在を確認します。
    ///
    /// - Returns: 検証済み bundle resource root URL。
    private func bundleRootURLWithRequiredResources() throws -> URL {
        let bundleRootURL = bundleResourceRootURL()?.standardizedFileURL
            ?? URL(fileURLWithPath: "/missing-bundle-resources")

        for directoryName in Self.seedDirectoryNames {
            let resourceURL = bundleRootURL.appendingPathComponent(directoryName, isDirectory: true)
            guard fileManager.fileExists(atPath: resourceURL.path) else {
                throw SampleProjectLocationError.missingBundleSeedResource(
                    name: directoryName,
                    url: resourceURL
                )
            }
        }

        let projectURL = bundleRootURL.appendingPathComponent(Self.projectRelativePath)
        guard fileManager.fileExists(atPath: projectURL.path) else {
            throw SampleProjectLocationError.missingBundleSeedResource(
                name: "OpenGraphiteSample.ogp",
                url: projectURL
            )
        }

        return bundleRootURL
    }
}

/// 論理名（日本語）: サンプルプロジェクト解決器
/// 概要: Debug 実行時の端末上 sample `.ogp` と、配布時の Application Support 上 sample `.ogp` のどちらを開くかを決定します。
///
/// プロパティ:
/// - `environment`: 実行環境変数。Debug scheme から sample `.ogp` のパスを受け取ります。
/// - `seedInstaller`: bundle seed を編集用コピーへ展開する installer。
struct SampleProjectLocator {
    static let sampleProjectPathEnvironmentKey = "OPENGRAPHITE_SAMPLE_PROJECT_PATH"

    private let environment: [String: String]
    private let seedInstaller: SampleSeedInstaller

    /// 論理名（日本語）: サンプルプロジェクト解決器初期化関数
    /// 処理概要: 環境変数と seed installer を注入可能な形で保持します。
    ///
    /// - Parameters:
    ///   - environment: 参照する環境変数。
    ///   - seedInstaller: Release/no-env 時に編集用 sample を用意する installer。
    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        seedInstaller: SampleSeedInstaller = SampleSeedInstaller()
    ) {
        self.environment = environment
        self.seedInstaller = seedInstaller
    }

    /// 論理名（日本語）: サンプルプロジェクトURL解決関数
    /// 処理概要: 環境変数で指定された端末上の sample `.ogp` を優先し、no-env 時は Application Support の編集用 sample を返します。
    ///
    /// - Returns: 読み込み対象の sample `.ogp` URL。
    func sampleProjectURL() throws -> URL {
        if let sampleProjectPath = environment[Self.sampleProjectPathEnvironmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !sampleProjectPath.isEmpty {
            let candidateURL = URL(fileURLWithPath: sampleProjectPath)
                .standardizedFileURL

            if FileManager.default.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }

            throw SampleProjectLocationError.missingEnvironmentSampleProject(candidateURL)
        }

        return try seedInstaller.installedSampleProjectURL()
    }
}
