import Foundation

/// 論理名（日本語）: テキストセクション表示モデル
/// 概要: Text Inspector を標準 HTML 編集カードと registry 由来の条件付き依存性カードへ分解します。
///
/// プロパティ:
/// - `sourceLabel`: text source metadata の表示値。
/// - `primaryTitle`: 標準編集カードの見出し。
/// - `primarySourceLabel`: 標準編集カードの正本種別。
/// - `primaryValue`: HTML 本文または fallback の現在値。
/// - `dependencies`: Text section 内に追加表示する依存性カード一覧。
struct InspectorTextSectionModel {
    var sourceLabel: String
    var primaryTitle: String
    var primarySourceLabel: String
    var primaryValue: String
    var dependencies: [InspectorTextDependencyCardModel]

    /// 論理名（日本語）: テキストセクション表示モデル初期化関数
    /// 処理概要: 選択中 text node、Project 依存性、registry から標準カードと依存性カードを構成します。
    ///
    /// - Parameters:
    ///   - node: 表示対象の text node。
    ///   - activeLocale: active preview で解決された locale。
    ///   - activeResolvedEditable: active resolved text を OpenGraphite から保存できるか。
    ///   - i18nInspection: 実装資源から検出した i18n runtime 情報。
    ///   - i18nTextResourceValues: 選択中 i18n key に対する locale JSON 値。
    ///   - registry: Text section に追加依存性を提供する registry。
    init(
        node: OpenGraphiteNode,
        activeLocale: String?,
        activeResolvedEditable: Bool,
        i18nInspection: OpenGraphiteI18nRuntimeInspection?,
        i18nTextResourceValues: [String: String] = [:],
        registry: InspectorTextDependencyRegistry = .standard
    ) {
        sourceLabel = node.textSourceLabel
        primaryTitle = Self.primaryTitle(for: node)
        primarySourceLabel = "HTML"
        primaryValue = node.fallbackTextContent ?? node.textContent ?? ""

        let activeResolvedText = Self.activeResolvedText(
            locale: activeLocale,
            isEditable: activeResolvedEditable
        )
        let context = InspectorTextDependencyContext(
            node: node,
            activeResolvedText: activeResolvedText,
            projectDependencies: InspectorProjectDependencySnapshot(
                i18nRuntime: i18nInspection,
                i18nTextResourceValues: i18nTextResourceValues
            )
        )
        dependencies = registry.models(for: context)
    }

    /// 論理名（日本語）: 標準カードタイトル生成関数
    /// 処理概要: 外部 text source を持つ node では HTML fallback、literal text では Content を返します。
    ///
    /// - Parameter node: 表示対象の text node。
    /// - Returns: 標準 text 編集カードのタイトル。
    private static func primaryTitle(for node: OpenGraphiteNode) -> String {
        if node.fallbackTextContent != nil || node.textSourceLabel != "literal" {
            return "HTML Fallback"
        }
        return "Content"
    }

    /// 論理名（日本語）: Active Resolved文脈生成関数
    /// 処理概要: 空ではない locale がある場合だけ依存性 provider 向けの解決済み text 文脈を返します。
    ///
    /// - Parameters:
    ///   - locale: active preview で解決された locale。
    ///   - isEditable: active resolved text を OpenGraphite から保存できるか。
    /// - Returns: 有効な locale を持つ解決済み text 文脈。
    private static func activeResolvedText(
        locale: String?,
        isEditable: Bool
    ) -> InspectorTextActiveResolvedContext? {
        guard let locale = locale?.trimmingCharacters(in: .whitespacesAndNewlines),
              !locale.isEmpty
        else {
            return nil
        }
        return InspectorTextActiveResolvedContext(locale: locale, isEditable: isEditable)
    }
}
