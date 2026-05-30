import Foundation

/// 論理名（日本語）: OpenGraphite編集ノード
/// 概要: HTML 内の `data-og-id` 付き要素を Layers と Inspector で扱うための表示・編集モデルです。
///
/// プロパティ:
/// - `id`: `data-og-id` の値。
/// - `tagName`: HTML タグ名または独自タグ名。
/// - `type`: `data-og-type` の値。
/// - `layout`: `data-og-layout` の値。
/// - `role`: `data-og-role` の値。
/// - `cssVariables`: inline style から抽出した `--og-*` の値。
/// - `isHidden`: `data-og-hidden` による非表示状態。
/// - `isLocked`: `data-og-locked` によるロック状態。
/// - `depth`: DOM ツリー上の階層深度。
struct OpenGraphiteNode: Identifiable, Hashable {
    var id: String
    var tagName: String
    var type: String
    var layout: String?
    var role: String?
    var cssVariables: [String: String]
    var isHidden: Bool
    var isLocked: Bool
    var depth: Int

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
}

/// 論理名（日本語）: CSS変数変更要求
/// 概要: Inspector で編集された `--og-*` の値を WebView 側 DOM へ反映するための mutation です。
///
/// プロパティ:
/// - `sequence`: mutation の順序番号。
/// - `nodeID`: 対象ノードの `data-og-id`。
/// - `key`: CSS 変数名。
/// - `value`: 反映する CSS 変数値。
struct CSSVariableMutation: Equatable {
    var sequence: Int
    var nodeID: String
    var key: String
    var value: String
}

/// 論理名（日本語）: ノード属性変更要求
/// 概要: Inspector で編集された `data-og-*` 属性を WebView 側 DOM へ反映するための mutation です。
///
/// プロパティ:
/// - `sequence`: mutation の順序番号。
/// - `nodeID`: 対象ノードの `data-og-id`。
/// - `name`: 更新する属性名。
/// - `value`: 反映する属性値。
struct NodeAttributeMutation: Equatable {
    var sequence: Int
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
