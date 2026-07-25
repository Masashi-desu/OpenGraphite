import SwiftUI

/// 論理名（日本語）: サイドバー作業履歴ビュー
/// 概要: 統合Undo / Redo時系列を、操作時刻、対象名、種類別簡易プレビューとともに左カラムへ表示します。
struct SidebarHistoryView: View {
    @EnvironmentObject private var store: EditorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            historyHeader
                .padding(.top, EditorOverlayMetrics.titlebarInset)
                .padding(.horizontal, EditorColumnStyle.outerPadding)
                .padding(.bottom, 10)

            if store.historyItems.isEmpty {
                historyEmptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if !undoItems.isEmpty {
                            SidebarHistorySection(
                                title: "取り消し可能",
                                icon: .undoHistory,
                                items: undoItems
                            )
                        }

                        if !redoItems.isEmpty {
                            SidebarHistorySection(
                                title: "やり直し可能",
                                icon: .redoHistory,
                                items: redoItems
                            )
                        }
                    }
                    .padding(.horizontal, EditorColumnStyle.outerPadding)
                    .padding(.bottom, 14)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var undoItems: [EditorHistoryListItem] {
        store.historyItems.filter { $0.state == .undoable }
    }

    private var redoItems: [EditorHistoryListItem] {
        store.historyItems.filter { $0.state == .redoable }
    }

    @ViewBuilder
    private var historyHeader: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("作業履歴")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(store.historyItems.count)件")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            SidebarHistoryActionButton(
                icon: .undoHistory,
                help: "取り消す",
                isEnabled: store.canUndo,
                action: store.undoDocumentChange
            )
            SidebarHistoryActionButton(
                icon: .redoHistory,
                help: "やり直す",
                isEnabled: store.canRedo,
                action: store.redoDocumentChange
            )
        }
        .padding(.horizontal, 8)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: EditorColumnStyle.panelRadius)
                .fill(EditorColumnStyle.rowFill)
        )
    }

    @ViewBuilder
    private var historyEmptyState: some View {
        VStack(spacing: 10) {
            OpenGraphiteIconView(icon: .historyPanel, size: 24)
                .foregroundStyle(.tertiary)
            Text("作業履歴はまだありません")
                .font(.system(size: 12, weight: .medium))
            Text("HTML、スタイル、注釈、ガイド、参照配置の変更がここに表示されます。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.top, 48)
    }
}

/// 論理名（日本語）: サイドバー履歴操作ボタン
/// 概要: 作業履歴ヘッダーから一段ずつUndoまたはRedoを実行する小型ボタンです。
///
/// プロパティ:
/// - `icon`: UndoまたはRedoを表すアイコン。
/// - `help`: ヘルプとアクセシビリティラベル。
/// - `isEnabled`: 操作可能か。
/// - `action`: 押下時の履歴移動処理。
private struct SidebarHistoryActionButton: View {
    var icon: OpenGraphiteIcon
    var help: String
    var isEnabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            OpenGraphiteIconView(icon: icon, size: 14)
                .frame(width: 26, height: 26)
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.45))
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isEnabled ? EditorColumnStyle.elevatedRowFill : Color.clear)
        )
        .disabled(!isEnabled)
        .help(help)
        .accessibilityLabel(help)
    }
}

/// 論理名（日本語）: サイドバー履歴セクション
/// 概要: Undo可能項目またはRedo可能項目を見出しと履歴行のまとまりとして表示します。
///
/// プロパティ:
/// - `title`: セクション見出し。
/// - `icon`: UndoまたはRedoを表すアイコン。
/// - `items`: 新しい操作順に表示する履歴項目。
private struct SidebarHistorySection: View {
    var title: String
    var icon: OpenGraphiteIcon
    var items: [EditorHistoryListItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                OpenGraphiteIconView(icon: icon, size: 12)
                Text(title)
                Spacer(minLength: 0)
                Text("\(items.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)

            VStack(spacing: 5) {
                ForEach(items) { item in
                    SidebarHistoryRow(item: item)
                }
            }
        }
    }
}

/// 論理名（日本語）: サイドバー履歴行
/// 概要: 対象の簡易プレビュー、オブジェクト名、操作名、タイムスタンプを一つの履歴行に表示します。
///
/// プロパティ:
/// - `item`: 表示する履歴項目。
private struct SidebarHistoryRow: View {
    var item: EditorHistoryListItem

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            SidebarHistoryObjectPreview(kind: item.previewKind)
                .opacity(item.state == .redoable ? 0.62 : 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.objectName)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(item.timestamp.formatted(.dateTime.hour().minute().second()))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 4) {
                    OpenGraphiteIconView(
                        icon: item.state == .undoable ? .undoHistory : .redoHistory,
                        size: 10
                    )
                    Text(item.actionName)
                        .lineLimit(1)
                }
                .font(.system(size: 10))
                .foregroundStyle(item.state == .undoable ? Color.secondary : Color.accentColor)
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                .fill(item.state == .redoable ? EditorColumnStyle.accentFill.opacity(0.48) : EditorColumnStyle.rowFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: EditorColumnStyle.rowRadius)
                .stroke(
                    item.state == .redoable ? Color.accentColor.opacity(0.18) : EditorColumnStyle.separatorColor,
                    lineWidth: 0.5
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.objectName)、\(item.actionName)、\(item.timestamp.formatted(.dateTime.hour().minute().second()))")
    }
}

/// 論理名（日本語）: サイドバー履歴オブジェクト簡易プレビュー
/// 概要: HTMLオブジェクト、付箋、手書き、ガイド、参照配置を履歴行左端の小型サムネイルとして描き分けます。
///
/// プロパティ:
/// - `kind`: 描画する対象種別と代表表示値。
private struct SidebarHistoryObjectPreview: View {
    var kind: EditorHistoryPreviewKind

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(EditorColumnStyle.elevatedRowFill)

            switch kind {
            case let .node(type):
                nodePreview(type: type)
            case let .stickyNote(backgroundColor, text):
                stickyNotePreview(backgroundColor: backgroundColor, text: text)
            case let .ink(color):
                inkPreview(color: color)
            case let .guide(orientation):
                guidePreview(orientation: orientation)
            case .reference:
                referencePreview
            }
        }
        .frame(width: 42, height: 36)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(EditorColumnStyle.separatorColor, lineWidth: 0.5)
        )
        .clipped()
        .accessibilityHidden(true)
    }

    /// 論理名（日本語）: HTMLオブジェクト簡易プレビュー
    /// 処理概要: pageまたはnodeを表すミニカードと種別アイコンを描画します。
    ///
    /// - Parameter type: `data-og-type`。
    /// - Returns: HTMLオブジェクトの簡易プレビュー。
    private func nodePreview(type: String) -> some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.primary.opacity(0.08))
                .frame(width: 28, height: 24)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 3) {
                        Capsule().fill(Color.primary.opacity(0.35)).frame(width: 16, height: 2)
                        Capsule().fill(Color.primary.opacity(0.18)).frame(width: 21, height: 2)
                        Capsule().fill(Color.primary.opacity(0.18)).frame(width: 13, height: 2)
                    }
                    .padding(5)
                }

            OpenGraphiteIconView(icon: .layerType(type), size: 11)
                .foregroundStyle(Color.accentColor)
                .padding(3)
                .background(.bar, in: RoundedRectangle(cornerRadius: 3))
        }
    }

    /// 論理名（日本語）: 付箋簡易プレビュー
    /// 処理概要: 保存色と本文量を反映した付箋カードを描画します。
    ///
    /// - Parameters:
    ///   - backgroundColor: 付箋のCSS背景色。
    ///   - text: 付箋本文。
    /// - Returns: 付箋の簡易プレビュー。
    private func stickyNotePreview(backgroundColor: String, text: String) -> some View {
        let noteColor = CSSColorValue(cssString: backgroundColor)?.color ?? Color.yellow
        return RoundedRectangle(cornerRadius: 3)
            .fill(noteColor)
            .frame(width: 27, height: 25)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(0..<min(max(text.split(whereSeparator: \Character.isWhitespace).count, 2), 4), id: \.self) { index in
                        Capsule()
                            .fill(Color.black.opacity(0.34))
                            .frame(width: index == 3 ? 11 : 18, height: 2)
                    }
                }
                .padding(5)
            }
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }

    /// 論理名（日本語）: 手書き簡易プレビュー
    /// 処理概要: 履歴対象strokeの代表色で短い手書き軌跡を描画します。
    ///
    /// - Parameter color: 手書きstrokeのCSS色。
    /// - Returns: 手書きの簡易プレビュー。
    private func inkPreview(color: String) -> some View {
        let strokeColor = CSSColorValue(cssString: color)?.color ?? Color.pink
        return Path { path in
            path.move(to: CGPoint(x: 7, y: 24))
            path.addCurve(
                to: CGPoint(x: 33, y: 11),
                control1: CGPoint(x: 12, y: 4),
                control2: CGPoint(x: 23, y: 31)
            )
            path.addCurve(
                to: CGPoint(x: 34, y: 25),
                control1: CGPoint(x: 39, y: 5),
                control2: CGPoint(x: 26, y: 18)
            )
        }
        .stroke(strokeColor, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
    }

    /// 論理名（日本語）: ガイド簡易プレビュー
    /// 処理概要: 水平または垂直のガイド線と座標目盛りを描画します。
    ///
    /// - Parameter orientation: ガイド方向。
    /// - Returns: ガイドの簡易プレビュー。
    private func guidePreview(orientation: OpenGraphiteCanvasGuideOrientation) -> some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 1, height: 4)
                    .offset(x: CGFloat(index * 8 - 12), y: -13)
            }

            Rectangle()
                .fill(Color.accentColor)
                .frame(
                    width: orientation == .horizontal ? 34 : 1,
                    height: orientation == .horizontal ? 1 : 29
                )
        }
    }

    /// 論理名（日本語）: 参照配置簡易プレビュー
    /// 処理概要: 参照元とCanvas配置を重ねたミニカードとして描画します。
    @ViewBuilder
    private var referencePreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.secondary.opacity(0.45), lineWidth: 1)
                .frame(width: 23, height: 18)
                .offset(x: -4, y: -3)
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.accentColor.opacity(0.20))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.accentColor.opacity(0.75), lineWidth: 1)
                )
                .frame(width: 23, height: 18)
                .offset(x: 4, y: 3)
            OpenGraphiteIconView(icon: .parameterLink, size: 10)
                .foregroundStyle(Color.accentColor)
        }
    }
}
