import SwiftUI

/// 論理名（日本語）: インスペクターテキスト値編集
/// 概要: 複数行になり得る text content を編集し、入力中は live 反映、フォーカスアウトと適用ボタンで保存します。
///
/// プロパティ:
/// - `label`: 値の種類。
/// - `value`: 現在の text content。
/// - `onPreview`: 入力中の app 内 cache 反映時に呼び出す処理。
/// - `onCommit`: 確定保存時に呼び出す処理。
struct InspectorEditableTextValueBlock: View {
    var label: String
    var value: String
    var onPreview: (String) -> Void
    var onCommit: (String, String) -> Bool

    @State private var draft: String
    @State private var committedValue: String
    @FocusState private var isFocused: Bool

    /// 論理名（日本語）: インスペクターテキスト値編集初期化関数
    /// 処理概要: 現在値を draft / 確定済み基準値へコピーし、live 反映処理と保存処理を保持します。
    ///
    /// - Parameters:
    ///   - label: 値の種類。
    ///   - value: 現在の text content。
    ///   - onPreview: 入力中の app 内 cache 反映時に呼び出す処理。
    ///   - onCommit: 保存時に呼び出す処理。
    init(
        label: String,
        value: String,
        onPreview: @escaping (String) -> Void,
        onCommit: @escaping (String, String) -> Bool
    ) {
        self.label = label
        self.value = value
        self.onPreview = onPreview
        self.onCommit = onCommit
        _draft = State(initialValue: value)
        _committedValue = State(initialValue: value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: commitIfChanged) {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .frame(width: 22, height: 20)
                }
                .buttonStyle(.plain)
                .foregroundStyle(hasChanges ? Color.accentColor : Color.secondary)
                .disabled(!hasChanges)
                .help("Apply text")
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $draft)
                    .font(.caption)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .frame(minHeight: 72, maxHeight: 132)
                    .focused($isFocused)

                if draft.isEmpty {
                    Text("empty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
            .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
            .overlay(
                RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                    .stroke(isFocused ? Color.accentColor.opacity(0.55) : EditorColumnStyle.separatorColor, lineWidth: 1)
            )
        }
        .onChange(of: value) { _, newValue in
            guard !isFocused else { return }
            draft = newValue
            committedValue = newValue
        }
        .onChange(of: draft) { _, _ in
            guard isFocused else { return }
            onPreview(draft)
        }
        .onChange(of: isFocused) { _, isFocused in
            guard !isFocused else { return }
            commitIfChanged()
        }
        .onDisappear {
            commitIfChanged()
        }
    }

    private var hasChanges: Bool {
        draft != committedValue
    }

    /// 論理名（日本語）: インスペクターテキスト値変更時適用関数
    /// 処理概要: draft が最後に保存できた値と異なる場合だけ text content を確定保存します。
    private func commitIfChanged() {
        guard hasChanges else { return }
        if onCommit(draft, committedValue) {
            committedValue = draft
        }
    }
}

/// 論理名（日本語）: インスペクターテキスト値表示
/// 概要: 複数行になり得る text content を読み取り専用で表示します。
///
/// プロパティ:
/// - `label`: 値の種類。
/// - `value`: 表示する text content。
struct InspectorTextValueBlock: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(displayValue)
                .font(.caption)
                .textSelection(.enabled)
                .foregroundStyle(isEmpty ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 9)
                .padding(.vertical, 8)
                .background(EditorColumnStyle.elevatedRowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                        .stroke(EditorColumnStyle.separatorColor, lineWidth: 1)
                )
        }
    }

    private var displayValue: String {
        isEmpty ? "empty" : value
    }

    private var isEmpty: Bool {
        value.isEmpty
    }
}
