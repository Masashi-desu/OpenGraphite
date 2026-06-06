import SwiftUI

/// 論理名（日本語）: インスペクター連動パラメータグループ
/// 概要: 連動中の入力群へ淡い背景色を付け、同じ状態に属するパラメータを視覚化します。
///
/// プロパティ:
/// - `isActive`: 連動表示を有効にするか。
/// - `content`: 内包する入力欄。
struct InspectorLinkedParameterGroup<Content: View>: View {
    var isActive: Bool
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            if isActive {
                RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius)
                    .fill(Color.accentColor.opacity(0.055))
            }

            content
                .padding(4)
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.16), value: isActive)
    }
}

/// 論理名（日本語）: インスペクター連動切替ボタン
/// 概要: リンクアイコンでパラメータ連動状態を切り替える小型ボタンです。
///
/// プロパティ:
/// - `isOn`: 現在の連動状態。
/// - `label`: アクセシビリティ用ラベル。
/// - `activeHelp`: 有効時の tooltip。
/// - `inactiveHelp`: 無効時の tooltip。
/// - `action`: 押下時の処理。
struct InspectorLinkedParameterButton: View {
    var isOn: Bool
    var label: String
    var activeHelp: String
    var inactiveHelp: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            OpenGraphiteIconView(icon: isOn ? .parameterLink : .parameterUnlink, size: 14)
                .frame(width: 30, height: 28)
                .foregroundStyle(isOn ? Color.white : Color.secondary)
                .background(
                    RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                        .fill(isOn ? Color.accentColor : EditorColumnStyle.elevatedRowFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                        .stroke(isOn ? Color.accentColor.opacity(0.68) : EditorColumnStyle.separatorColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(isOn ? activeHelp : inactiveHelp)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "有効" : "無効")
    }
}
