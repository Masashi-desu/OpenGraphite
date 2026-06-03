import Foundation

/// 論理名（日本語）: OpenGraphite編集ノード
/// 概要: HTML 内の `data-og-id` 付き要素を Layers と Inspector で扱うための表示・編集モデルです。
///
/// プロパティ:
/// - `id`: `data-og-id` の値。
/// - `internalID`: `data-og-internal-id` の値。
/// - `tagName`: HTML タグ名または独自タグ名。
/// - `type`: `data-og-type` の値。
/// - `layout`: `data-og-layout` の値。
/// - `role`: `data-og-role` の値。
/// - `componentID`: `data-og-component` の値。
/// - `componentKind`: `data-og-component-kind` の値。
/// - `sourceComponentID`: runtime 展開後の `data-og-source-component` の値。
/// - `sourceInstanceID`: runtime 展開後の `data-og-source-instance` の値。
/// - `cssVariables`: inline style から抽出した `--og-*` の値。
/// - `isHidden`: `data-og-hidden` による非表示状態。
/// - `isLocked`: `data-og-locked` によるロック状態。
/// - `depth`: DOM ツリー上の階層深度。
struct OpenGraphiteNode: Identifiable, Hashable {
    var id: String
    var internalID: String = ""
    var tagName: String
    var type: String
    var layout: String?
    var role: String?
    var componentID: String?
    var componentKind: String?
    var sourceComponentID: String?
    var sourceInstanceID: String?
    var cssVariables: [String: String]
    var isHidden: Bool
    var isLocked: Bool
    var depth: Int

    /// 論理名（日本語）: OpenGraphite編集ノード初期化関数
    /// 処理概要: HTML ノードの表示 ID、内部 ID、編集メタデータから UI モデルを構成します。
    ///
    /// - Parameters:
    ///   - id: `data-og-id`。
    ///   - internalID: `data-og-internal-id`。
    ///   - tagName: HTML tag name。
    ///   - type: `data-og-type`。
    ///   - layout: `data-og-layout`。
    ///   - role: `data-og-role`。
    ///   - componentID: `data-og-component`。
    ///   - componentKind: `data-og-component-kind`。
    ///   - sourceComponentID: `data-og-source-component`。
    ///   - sourceInstanceID: `data-og-source-instance`。
    ///   - cssVariables: inline style 内の `--og-*`。
    ///   - isHidden: 非表示状態。
    ///   - isLocked: ロック状態。
    ///   - depth: DOM 階層深度。
    init(
        id: String,
        internalID: String = "",
        tagName: String,
        type: String,
        layout: String?,
        role: String?,
        componentID: String? = nil,
        componentKind: String? = nil,
        sourceComponentID: String? = nil,
        sourceInstanceID: String? = nil,
        cssVariables: [String: String],
        isHidden: Bool,
        isLocked: Bool,
        depth: Int
    ) {
        self.id = id
        self.internalID = internalID
        self.tagName = tagName
        self.type = type
        self.layout = layout
        self.role = role
        self.componentID = Self.emptyNil(componentID)
        self.componentKind = Self.emptyNil(componentKind)
        self.sourceComponentID = Self.emptyNil(sourceComponentID)
        self.sourceInstanceID = Self.emptyNil(sourceInstanceID)
        self.cssVariables = cssVariables
        self.isHidden = isHidden
        self.isLocked = isLocked
        self.depth = depth
    }

    var inheritedComponentID: String? {
        if let sourceComponentID {
            return sourceComponentID
        }
        guard tagName == "og-instance", componentKind != "master" else {
            return nil
        }
        return componentID
    }

    var detailLine: String {
        var parts = [type]
        if let layout, !layout.isEmpty {
            parts.append(layout)
        }
        if let role, !role.isEmpty {
            parts.append(role)
        }
        if isHidden {
            parts.append("hidden")
        }
        if isLocked {
            parts.append("locked")
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// 論理名（日本語）: 空文字nil変換関数
    /// 処理概要: 属性値の前後空白を除去し、空文字を `nil` として保存します。
    ///
    /// - Parameter value: 正規化する属性値。
    /// - Returns: 空でない属性値。空の場合は `nil`。
    private static func emptyNil(_ value: String?) -> String? {
        guard let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !normalized.isEmpty
        else {
            return nil
        }
        return normalized
    }
}

/// 論理名（日本語）: OpenGraphiteコンポーネント継承元
/// 概要: 選択された component instance が参照する master の名称と配置情報を Inspector へ渡す表示モデルです。
///
/// プロパティ:
/// - `componentID`: master の `data-og-component`。
/// - `masterNodeID`: master root の `data-og-id`。
/// - `collectionInternalID`: master を含む Collection の内部 ID。
/// - `collectionName`: Collection の表示名。
/// - `componentPageID`: master を含む component canvas の ID。
/// - `componentPageInternalID`: master を含む component canvas の内部 ID。
/// - `componentPageName`: component canvas の表示名。
/// - `componentPagePath`: component canvas の HTML path。
/// - `canvas`: component canvas の配置情報。
struct OpenGraphiteComponentSource: Equatable, Identifiable {
    var componentID: String
    var masterNodeID: String?
    var collectionInternalID: String
    var collectionName: String
    var componentPageID: String
    var componentPageInternalID: String
    var componentPageName: String
    var componentPagePath: String
    var canvas: OpenGraphiteCanvas

    var id: String {
        "\(collectionInternalID):\(componentPageInternalID):\(componentID)"
    }

    var locationLabel: String {
        "\(collectionName) / \(componentPageName)"
    }

    var canvasLabel: String {
        "\(canvas.positionLabel) · \(canvas.resolutionLabel)"
    }
}

/// 論理名（日本語）: CSS変数変更要求
/// 概要: Inspector で編集された `--og-*` の値を WebView 側 DOM へ反映するための mutation です。
///
/// プロパティ:
/// - `sequence`: mutation の順序番号。
/// - `pageURL`: mutation を適用する HTML ファイル URL。
/// - `nodeID`: 対象ノードの `data-og-id`。
/// - `key`: CSS 変数名。
/// - `value`: 反映する CSS 変数値。
struct CSSVariableMutation: Equatable {
    var sequence: Int
    var pageURL: URL
    var nodeID: String
    var key: String
    var value: String
}

/// 論理名（日本語）: ノード属性変更要求
/// 概要: Inspector で編集された `data-og-*` 属性を WebView 側 DOM へ反映するための mutation です。
///
/// プロパティ:
/// - `sequence`: mutation の順序番号。
/// - `pageURL`: mutation を適用する HTML ファイル URL。
/// - `nodeID`: 対象ノードの `data-og-id`。
/// - `name`: 更新する属性名。
/// - `value`: 反映する属性値。
struct NodeAttributeMutation: Equatable {
    var sequence: Int
    var pageURL: URL
    var nodeID: String
    var name: String
    var value: String
}

/// 論理名（日本語）: キャンバス操作ツール
/// 概要: プレビュー上で利用する選択、図形、テキスト、フレーム、ハンドの各操作モードを表します。
///
/// 定義内容:
/// - `select`: ノード選択用の編集カーソル。
/// - `rectangle`: レクトアングル作成ツール。
/// - `text`: テキスト作成ツール。
/// - `frame`: フレーム作成ツール。
/// - `hand`: キャンバス移動用ツール。
enum CanvasTool: String, CaseIterable, Identifiable {
    case select
    case rectangle
    case text
    case frame
    case hand

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select:
            return "編集カーソル"
        case .rectangle:
            return "レクトアングル"
        case .text:
            return "テキスト"
        case .frame:
            return "フレーム"
        case .hand:
            return "ハンド"
        }
    }

    var systemImage: String {
        switch self {
        case .select:
            return "cursorarrow"
        case .rectangle:
            return "rectangle"
        case .text:
            return "textformat"
        case .frame:
            return "square.dashed"
        case .hand:
            return "hand.raised"
        }
    }
}

/// 論理名（日本語）: プレビュー表示モード
/// 概要: 中央プレビューで通常編集表示と画面遷移フロー表示を切り替える状態を表します。
///
/// 定義内容:
/// - `normal`: 通常の編集プレビュー表示。
/// - `flow`: 静的リンクから解決した画面遷移線を重ねるフロー表示。
enum OpenGraphitePreviewDisplayMode: String, CaseIterable, Identifiable {
    case normal
    case flow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal:
            return "Normal"
        case .flow:
            return "Flow"
        }
    }

    var systemImage: String {
        switch self {
        case .normal:
            return "eye"
        case .flow:
            return "arrow.right"
        }
    }

    var help: String {
        switch self {
        case .normal:
            return "通常表示"
        case .flow:
            return "フロー表示"
        }
    }
}
