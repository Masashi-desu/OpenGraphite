import SwiftUI

/// 論理名（日本語）: インスペクターセクション
/// 概要: Inspector 内の見出し付きパネルを共通化する汎用コンテナです。
///
/// プロパティ:
/// - `title`: セクション見出し。
/// - `sectionID`: Preview 側編集と対応付ける Inspector セクション ID。
/// - `content`: セクション内に表示する SwiftUI content。
struct InspectorSection<Content: View>: View {
    @EnvironmentObject private var store: EditorStore

    var title: String
    var sectionID: InspectorSectionID?
    var content: Content

    @State private var isExpanded = false

    /// 論理名（日本語）: インスペクターセクション初期化関数
    /// 処理概要: 見出し、Preview 編集との対応 ID、カード内 content を保持します。
    ///
    /// - Parameters:
    ///   - title: セクション見出し。
    ///   - sectionID: Preview 側編集と対応付ける Inspector セクション ID。
    ///   - content: セクション内に表示する SwiftUI content。
    init(title: String, sectionID: InspectorSectionID? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.sectionID = sectionID
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                OpenGraphiteIconView(icon: headerIcon, size: 13, weight: .semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)

                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "\(title) を閉じる" : "\(title) を開く")
                .help(isExpanded ? "\(title) を閉じる" : "\(title) を開く")
            }
            .padding(.horizontal, 10)
            .frame(height: 34)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    content
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EditorColumnStyle.rowFill, in: RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius))
        .overlay(
            RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius)
                .stroke(EditorColumnStyle.separatorColor, lineWidth: 1)
        )
        .onAppear {
            expandIfRequested()
        }
        .onChange(of: store.inspectorExpansionScopeIdentifier) { _, _ in
            isExpanded = false
        }
        .onChange(of: store.inspectorSectionOpenRequest?.sequence) { _, _ in
            expandIfRequested()
        }
    }

    private var headerIcon: OpenGraphiteIcon {
        guard let sectionID else {
            return .lucide("panel-right", fallbackSystemName: "sidebar.right")
        }
        return .inspectorSection(sectionID)
    }

    /// 論理名（日本語）: 要求反映関数
    /// 処理概要: 現在選択スコープに一致する Preview 編集要求がこのカードを指している場合だけカードを開きます。
    private func expandIfRequested() {
        guard let sectionID,
              let request = store.inspectorSectionOpenRequest,
              request.scopeIdentifier == store.inspectorExpansionScopeIdentifier,
              request.sectionIDs.contains(sectionID)
        else {
            return
        }

        withAnimation(.easeInOut(duration: 0.16)) {
            isExpanded = true
        }
    }
}

/// 論理名（日本語）: インスペクター情報行
/// 概要: 編集不可のラベルと値を左右に並べて表示します。
///
/// プロパティ:
/// - `label`: 項目名。
/// - `value`: 表示値。
struct InspectorInfoRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.caption)
    }
}
