import SwiftUI

/// 論理名（日本語）: インスペクター依存性カード
/// 概要: 依存性の種類、状態、補足、任意の action を共通 chrome として表示します。
///
/// プロパティ:
/// - `model`: 依存性カードの共通表示モデル。
/// - `onAction`: action ボタン押下時の処理。
/// - `content`: 依存性ごとの固有 UI。
struct InspectorDependencyCard<Content: View>: View {
    var model: InspectorDependencyCardModel
    var onAction: @MainActor (InspectorDependencyCardAction) -> Void
    var content: Content

    /// 論理名（日本語）: インスペクター依存性カード初期化関数
    /// 処理概要: 共通表示モデル、任意 action、固有 UI を保持します。
    ///
    /// - Parameters:
    ///   - model: 依存性カードの共通表示モデル。
    ///   - onAction: action ボタン押下時の処理。
    ///   - content: 依存性ごとの固有 UI。
    init(
        model: InspectorDependencyCardModel,
        onAction: @escaping @MainActor (InspectorDependencyCardAction) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.model = model
        self.onAction = onAction
        self.content = content()
    }

    var body: some View {
        InspectorSubsectionCard {
            InspectorCardHeader(
                title: model.title,
                leadingSystemImage: model.status.systemImage,
                pills: [
                    InspectorCardPill(label: model.sourceLabel, tone: .neutral),
                    InspectorCardPill(label: model.status.label, tone: model.status.pillTone)
                ]
            )

            if let detail = model.detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content

            if let action = model.action {
                Button {
                    onAction(action)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.square")
                        Text(action.title)
                        Spacer()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                            .stroke(Color.accentColor.opacity(0.24), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 論理名（日本語）: インスペクター内部カード
/// 概要: InspectorSection 内で標準編集面や依存性面を区切る小さなカード面です。
///
/// プロパティ:
/// - `content`: カード内部に配置する UI。
struct InspectorSubsectionCard<Content: View>: View {
    var content: Content

    /// 論理名（日本語）: インスペクター内部カード初期化関数
    /// 処理概要: カード内部 UI を保持します。
    ///
    /// - Parameter content: カード内部に配置する UI。
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EditorColumnStyle.elevatedRowFill.opacity(0.62), in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
        .overlay(
            RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                .stroke(EditorColumnStyle.separatorColor, lineWidth: 1)
        )
    }
}

/// 論理名（日本語）: インスペクターカードヘッダー
/// 概要: 内部カードのタイトル、アイコン、状態 pill を表示します。
///
/// プロパティ:
/// - `title`: カードタイトル。
/// - `leadingSystemImage`: 先頭に表示する SF Symbols 名。
/// - `pills`: 状態や正本種別の pill 一覧。
struct InspectorCardHeader: View {
    var title: String
    var leadingSystemImage: String
    var pills: [InspectorCardPill]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: leadingSystemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            HStack(spacing: 5) {
                ForEach(pills) { pill in
                    InspectorCardPillView(pill: pill)
                }
            }
        }
    }
}

/// 論理名（日本語）: インスペクターカードpill
/// 概要: 内部カードヘッダーで使う短い状態ラベルを表します。
///
/// プロパティ:
/// - `id`: 表示識別子。
/// - `label`: pill に表示する文字列。
/// - `tone`: pill の意味色。
struct InspectorCardPill: Identifiable {
    var id: String { "\(label)-\(tone)" }
    var label: String
    var tone: InspectorCardPillTone
}

/// 論理名（日本語）: インスペクターカードpill色調
/// 概要: pill が neutral / success / warning / secondary のどの意味色かを表します。
///
/// 定義内容:
/// - `neutral`: 種類や正本名などの中立情報。
/// - `success`: 編集可能などの良好状態。
/// - `warning`: missing や未設定など注意が必要な状態。
/// - `secondary`: read-only など補助的な状態。
enum InspectorCardPillTone: String {
    case neutral
    case success
    case warning
    case secondary
}

/// 論理名（日本語）: インスペクターカードpillビュー
/// 概要: 内部カードヘッダーの短い状態ラベルを描画します。
///
/// プロパティ:
/// - `pill`: 表示する pill モデル。
private struct InspectorCardPillView: View {
    var pill: InspectorCardPill

    var body: some View {
        Text(pill.label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(pill.tone.foregroundColor)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(pill.tone.backgroundColor, in: Capsule())
    }
}

private extension InspectorDependencyStatus {
    var systemImage: String {
        switch self {
        case .editable:
            return "checkmark.circle"
        case .readOnly:
            return "lock"
        case .missing:
            return "exclamationmark.triangle"
        case .notConfigured:
            return "gearshape"
        case .external:
            return "link"
        }
    }

    var pillTone: InspectorCardPillTone {
        switch self {
        case .editable:
            return .success
        case .readOnly:
            return .secondary
        case .missing, .notConfigured:
            return .warning
        case .external:
            return .secondary
        }
    }
}

private extension InspectorCardPillTone {
    var foregroundColor: Color {
        switch self {
        case .neutral:
            return .secondary
        case .success:
            return .green
        case .warning:
            return .orange
        case .secondary:
            return .secondary
        }
    }

    var backgroundColor: Color {
        switch self {
        case .neutral:
            return EditorColumnStyle.rowFill
        case .success:
            return Color.green.opacity(0.12)
        case .warning:
            return Color.orange.opacity(0.13)
        case .secondary:
            return EditorColumnStyle.rowFill
        }
    }
}
