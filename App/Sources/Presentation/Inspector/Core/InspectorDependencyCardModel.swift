import Foundation

/// 論理名（日本語）: インスペクター依存性状態
/// 概要: Inspector セクション内の依存性カードが編集可能、未設定、外部管理などのどの状態かを表します。
///
/// 定義内容:
/// - `editable`: OpenGraphite から正本へ書き戻せる状態。
/// - `readOnly`: 正本は検出できたが、この画面から編集しない状態。
/// - `missing`: 依存資源や active context が不足している状態。
/// - `notConfigured`: 依存性自体が未導入または未設定の状態。
/// - `external`: 外部式や未対応 runtime のため OpenGraphite が所有しない状態。
enum InspectorDependencyStatus: String, Equatable {
    case editable
    case readOnly
    case missing
    case notConfigured
    case external

    var label: String {
        switch self {
        case .editable:
            return "Editable"
        case .readOnly:
            return "Read only"
        case .missing:
            return "Missing"
        case .notConfigured:
            return "Not configured"
        case .external:
            return "External"
        }
    }
}

/// 論理名（日本語）: インスペクター依存性カードアクション
/// 概要: 依存性カードから Project 資源などへ移動する action を表します。
///
/// プロパティ:
/// - `title`: ボタンに表示する短い文言。
/// - `projectResource`: Project セグメントで選択する資源。移動先がない action では `nil`。
struct InspectorDependencyCardAction: Equatable {
    var title: String
    var projectResource: OpenGraphiteProjectResourceSelection?
}

/// 論理名（日本語）: インスペクター依存性カードモデル
/// 概要: Inspector section 内に追加依存性カードを描画するための共通表示モデルです。
///
/// プロパティ:
/// - `id`: カード識別子。
/// - `title`: カード見出し。
/// - `sourceLabel`: 正本や依存資源の種類。
/// - `status`: 依存性の検出・編集状態。
/// - `detail`: 状態を補足する短い説明。
/// - `action`: 任意の移動または修復 action。
struct InspectorDependencyCardModel: Identifiable, Equatable {
    var id: String
    var title: String
    var sourceLabel: String
    var status: InspectorDependencyStatus
    var detail: String?
    var action: InspectorDependencyCardAction?
}
