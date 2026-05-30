import Foundation

/// 論理名（日本語）: エディター状態ストア
/// 概要: 読み込み済みプロジェクト、ページ選択、DOM ノード一覧、Inspector 変更要求を保持するメイン状態管理クラスです。
///
/// プロパティ:
/// - `loadedProject`: 現在開いている `.ogp`。
/// - `selectedPageID`: 選択中ページの ID。
/// - `nodes`: WebView から抽出された編集ノード一覧。
/// - `selectedNodeID`: 選択中ノードの `data-og-id`。
/// - `zoom`: キャンバス表示倍率。
/// - `activeTool`: キャンバス上の選択ツール。
/// - `cssMutation`: WebView へ反映待ちの CSS 変数変更。
/// - `attributeMutation`: WebView へ反映待ちの属性変更。
@MainActor
final class EditorStore: ObservableObject {
    @Published private(set) var loadedProject: LoadedOpenGraphiteProject?
    @Published var selectedPageID: String?
    @Published private(set) var nodes: [OpenGraphiteNode] = []
    @Published var selectedNodeID: String?
    @Published var zoom: Double = 0.72
    @Published var statusMessage = "HTMLを正本として開きます。"
    @Published var lastError: String?
    @Published var activeTool: CanvasTool = .select
    @Published private(set) var cssMutation: CSSVariableMutation?
    @Published private(set) var attributeMutation: NodeAttributeMutation?

    private let loader = ProjectLoader()
    private var mutationSequence = 0
    private var attributeMutationSequence = 0

    var selectedPage: OpenGraphitePage? {
        guard let loadedProject else { return nil }
        return loadedProject.project.pages.first { $0.id == selectedPageID }
            ?? loadedProject.project.pages.first
    }

    var selectedPageURL: URL? {
        guard let loadedProject, let selectedPage else { return nil }
        return loadedProject.htmlURL(for: selectedPage)
    }

    var projectRootURL: URL? {
        loadedProject?.rootURL
    }

    var selectedNode: OpenGraphiteNode? {
        guard let selectedNodeID else { return nil }
        return nodes.first { $0.id == selectedNodeID }
    }

    /// 論理名（日本語）: サンプルプロジェクトオープン関数
    /// 処理概要: アプリバンドル内の `OpenGraphiteSample.ogp` を探し、見つかった場合は読み込みます。
    func openSampleProject() {
        guard let url = Bundle.main.url(
            forResource: "OpenGraphiteSample",
            withExtension: "ogp",
            subdirectory: "SampleProject"
        ) else {
            lastError = "バンドル内のサンプルプロジェクトが見つかりません。"
            return
        }

        openProject(at: url)
    }

    /// 論理名（日本語）: パネル経由プロジェクトオープン関数
    /// 処理概要: ファイル選択パネルから `.ogp` を選ばせ、選択された URL を読み込みます。
    func openProjectWithPanel() {
        guard let url = ProjectDialogs.openProjectURL() else { return }
        openProject(at: url)
    }

    /// 論理名（日本語）: プロジェクトオープン関数
    /// 処理概要: 指定された `.ogp` を読み込み、ページ選択とノード状態を初期化します。
    ///
    /// - Parameter url: 読み込む `.ogp` の URL。
    func openProject(at url: URL) {
        do {
            let project = try loader.loadProject(at: url)
            loadedProject = project
            selectedPageID = project.project.pages.first?.id
            selectedNodeID = nil
            nodes = []
            cssMutation = nil
            attributeMutation = nil
            statusMessage = "\(project.project.name) を開きました。"
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// 論理名（日本語）: ページ選択関数
    /// 処理概要: 選択ページを切り替え、ページ変更時にノード選択と DOM ノード一覧をリセットします。
    ///
    /// - Parameter id: 選択するページ ID。`nil` の場合は先頭ページが表示対象になります。
    func selectPage(id: String?) {
        selectedPageID = id
        selectedNodeID = nil
        nodes = []
        if let page = selectedPage {
            statusMessage = "\(page.path) を表示しています。"
        }
    }

    /// 論理名（日本語）: ノード選択関数
    /// 処理概要: Layers、Canvas、Context Menu から渡された `data-og-id` を選択状態として保存します。
    ///
    /// - Parameter id: 選択するノード ID。選択解除時は `nil`。
    func selectNode(id: String?) {
        selectedNodeID = id
    }

    /// 論理名（日本語）: ノードpayload取り込み関数
    /// 処理概要: WebView の JavaScript から受け取った辞書配列を `OpenGraphiteNode` 配列へ変換します。
    ///
    /// - Parameter payload: DOM から収集されたノード辞書の配列。
    func ingestNodePayload(_ payload: [[String: Any]]) {
        nodes = payload.compactMap(Self.node(from:))

        if let selectedNodeID, !nodes.contains(where: { $0.id == selectedNodeID }) {
            self.selectedNodeID = nil
        }
    }

    /// 論理名（日本語）: CSS変数更新関数
    /// 処理概要: 選択中ノードの CSS 変数を更新し、WebView へ反映する mutation を発行します。
    ///
    /// - Parameters:
    ///   - key: 更新する `--og-*` 変数名。
    ///   - value: Inspector から入力された値。前後空白は除去します。
    func updateCSSVariable(key: String, value: String) {
        guard let selectedNodeID else { return }
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) {
            if normalizedValue.isEmpty {
                nodes[index].cssVariables.removeValue(forKey: key)
            } else {
                nodes[index].cssVariables[key] = normalizedValue
            }
        }

        mutationSequence += 1
        cssMutation = CSSVariableMutation(
            sequence: mutationSequence,
            nodeID: selectedNodeID,
            key: key,
            value: normalizedValue
        )
        statusMessage = "\(selectedNodeID) の \(key) を更新しました。"
    }

    /// 論理名（日本語）: ノード属性更新関数
    /// 処理概要: 選択中ノードの編集対象属性を更新し、WebView へ反映する mutation を発行します。
    ///
    /// - Parameters:
    ///   - name: 更新する属性名。
    ///   - value: Inspector から入力された値。空の場合は属性削除として扱います。
    func updateNodeAttribute(name: String, value: String) {
        guard let selectedNodeID else { return }
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if let index = nodes.firstIndex(where: { $0.id == selectedNodeID }) {
            switch name {
            case "data-og-layout":
                nodes[index].layout = normalizedValue.isEmpty ? nil : normalizedValue
            case "data-og-role":
                nodes[index].role = normalizedValue.isEmpty ? nil : normalizedValue
            default:
                break
            }
        }

        attributeMutationSequence += 1
        attributeMutation = NodeAttributeMutation(
            sequence: attributeMutationSequence,
            nodeID: selectedNodeID,
            name: name,
            value: normalizedValue
        )
        statusMessage = "\(selectedNodeID) の \(name) を更新しました。"
    }

    /// 論理名（日本語）: CSS変数mutation適用完了関数
    /// 処理概要: WebView への反映が完了した CSS mutation を順序番号で確認してクリアします。
    ///
    /// - Parameter sequence: 適用完了した mutation の順序番号。
    func markMutationApplied(sequence: Int) {
        guard cssMutation?.sequence == sequence else { return }
        cssMutation = nil
    }

    /// 論理名（日本語）: 属性mutation適用完了関数
    /// 処理概要: WebView への反映が完了した属性 mutation を順序番号で確認してクリアします。
    ///
    /// - Parameter sequence: 適用完了した mutation の順序番号。
    func markAttributeMutationApplied(sequence: Int) {
        guard attributeMutation?.sequence == sequence else { return }
        attributeMutation = nil
    }

    /// 論理名（日本語）: 現在HTML保存関数
    /// 処理概要: WebView からシリアライズされた HTML を現在選択中ページのファイルへ保存します。
    ///
    /// - Parameter html: 保存する HTML 文字列。
    func persistCurrentHTML(_ html: String) {
        guard let selectedPageURL else { return }

        do {
            try html.write(to: selectedPageURL, atomically: true, encoding: .utf8)
            statusMessage = "\(selectedPageURL.lastPathComponent) に保存しました。"
        } catch {
            lastError = "HTMLの保存に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 論理名（日本語）: WebViewエラー報告関数
    /// 処理概要: WebView や JavaScript ブリッジで発生したエラー文を画面表示用に保存します。
    ///
    /// - Parameter message: 表示するエラーメッセージ。
    func reportWebError(_ message: String) {
        lastError = message
    }

    /// 論理名（日本語）: ノード辞書変換関数
    /// 処理概要: JavaScript 由来の辞書から必須項目を検証し、`OpenGraphiteNode` を生成します。
    ///
    /// - Parameter dictionary: DOM ノードから収集した辞書。
    /// - Returns: 必須値がそろっている場合はノード、欠けている場合は `nil`。
    private static func node(from dictionary: [String: Any]) -> OpenGraphiteNode? {
        guard
            let id = dictionary["id"] as? String,
            !id.isEmpty,
            let tagName = dictionary["tagName"] as? String,
            let type = dictionary["type"] as? String
        else {
            return nil
        }

        let cssVariables = dictionary["cssVariables"] as? [String: String] ?? [:]
        return OpenGraphiteNode(
            id: id,
            tagName: tagName,
            type: type,
            layout: dictionary["layout"] as? String,
            role: dictionary["role"] as? String,
            cssVariables: cssVariables,
            isHidden: dictionary["hidden"] as? Bool ?? false,
            isLocked: dictionary["locked"] as? Bool ?? false,
            depth: dictionary["depth"] as? Int ?? 0
        )
    }
}
