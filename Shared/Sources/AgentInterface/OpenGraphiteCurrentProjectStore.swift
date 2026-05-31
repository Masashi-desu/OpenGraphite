import Foundation

/// 論理名（日本語）: 現在プロジェクト記録
/// 概要: OpenGraphite app が最後に開いた `.ogp` を CLI / MCP から参照するための永続レコードです。
///
/// プロパティ:
/// - `schemaVersion`: レコード形式のバージョン。
/// - `projectURL`: 現在開いている `.ogp` の絶対 file URL 文字列。
/// - `updatedAt`: レコード更新時刻。
struct OpenGraphiteCurrentProjectRecord: Codable, Equatable {
    var schemaVersion: String
    var projectURL: String
    var updatedAt: String
}

/// 論理名（日本語）: 現在プロジェクトストア
/// 概要: OpenGraphite app と `ogkiln` が共有する「現在開いている `.ogp`」の読み書きを担当します。
///
/// プロパティ:
/// - `recordURL`: JSON レコードの保存先。
struct OpenGraphiteCurrentProjectStore {
    static let schemaVersion = "0.1"

    var recordURL: URL

    /// 論理名（日本語）: 現在プロジェクトストア初期化関数
    /// 処理概要: 明示された保存先、または Application Support 配下の既定保存先を使います。
    ///
    /// - Parameter recordURL: JSON レコードの保存先。
    init(recordURL: URL = OpenGraphiteCurrentProjectStore.defaultRecordURL()) {
        self.recordURL = recordURL
    }

    /// 論理名（日本語）: 既定レコードURL生成関数
    /// 処理概要: `~/Library/Application Support/OpenGraphite/current-project.json` を返します。
    ///
    /// - Returns: 既定の JSON レコード URL。
    static func defaultRecordURL() -> URL {
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return supportURL
            .appendingPathComponent("OpenGraphite", isDirectory: true)
            .appendingPathComponent("current-project.json")
    }

    /// 論理名（日本語）: 現在プロジェクト書き込み関数
    /// 処理概要: 指定 `.ogp` の絶対 URL を Application Support のレコードへ保存します。
    ///
    /// - Parameter projectURL: 現在開いている `.ogp` の URL。
    func write(projectURL: URL) throws {
        let standardizedURL = projectURL.standardizedFileURL
        let record = OpenGraphiteCurrentProjectRecord(
            schemaVersion: Self.schemaVersion,
            projectURL: standardizedURL.absoluteString,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(record)
        try FileManager.default.createDirectory(
            at: recordURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: recordURL, options: .atomic)
    }

    /// 論理名（日本語）: 現在プロジェクト読み込み関数
    /// 処理概要: 保存済みレコードから `.ogp` URL を復元し、ファイル存在を確認して返します。
    ///
    /// - Returns: 現在開いている `.ogp` の URL。
    func readProjectURL() throws -> URL {
        guard FileManager.default.fileExists(atPath: recordURL.path) else {
            throw OpenGraphiteCurrentProjectStoreError.missingRecord(recordURL)
        }

        let data = try Data(contentsOf: recordURL)
        let record = try JSONDecoder().decode(OpenGraphiteCurrentProjectRecord.self, from: data)
        guard let url = URL(string: record.projectURL), url.isFileURL else {
            throw OpenGraphiteCurrentProjectStoreError.invalidRecord(recordURL)
        }
        let standardizedURL = url.standardizedFileURL
        guard FileManager.default.fileExists(atPath: standardizedURL.path) else {
            throw OpenGraphiteCurrentProjectStoreError.missingProject(standardizedURL)
        }
        return standardizedURL
    }
}

/// 論理名（日本語）: 現在プロジェクトストアエラー
/// 概要: 現在プロジェクトレコードの欠落、破損、参照先欠落を表します。
///
/// 定義内容:
/// - `missingRecord`: current project レコードが存在しない。
/// - `invalidRecord`: レコード内容から file URL を復元できない。
/// - `missingProject`: レコードが指す `.ogp` が存在しない。
enum OpenGraphiteCurrentProjectStoreError: LocalizedError, Equatable {
    case missingRecord(URL)
    case invalidRecord(URL)
    case missingProject(URL)

    var errorDescription: String? {
        switch self {
        case .missingRecord(let url):
            return "現在開いている .ogp の記録がありません: \(url.path)"
        case .invalidRecord(let url):
            return "現在開いている .ogp の記録が不正です: \(url.path)"
        case .missingProject(let url):
            return "現在開いている .ogp が見つかりません: \(url.path)"
        }
    }
}
