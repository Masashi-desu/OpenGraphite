import Foundation

/// 論理名（日本語）: インスペクターセクション識別子
/// 概要: Inspector の折りたたみカードを CSS / 属性 / text 編集の種類から開くための安定 ID です。
///
/// 定義内容:
/// - `context`: ノードやページの基本情報カード。
/// - `component`: Component 継承元カード。
/// - `pages`: Chapter 内ページ一覧カード。
/// - `alignment`: align / justify カード。
/// - `layout`: layout、gap、padding、margin、flex カード。
/// - `position`: position、inset、z-index カード。
/// - `dimensions`: width / height 系カード。
/// - `appearance`: border、background、color 系カード。
/// - `text`: text content カード。
/// - `typography`: font / text-align カード。
/// - `media`: image object-fit カード。
/// - `icon`: icon metadata カード。
/// - `effects`: shadow / transform 系カード。
/// - `animation`: CSS animation カード。
/// - `scrollTimeline`: Scroll-driven animation カード。
/// - `htmlDocument`: HTML document attribute カード。
/// - `i18nRuntime`: i18n runtime カード。
/// - `localeTypography`: locale font カード。
/// - `mockState`: preview mock state カード。
/// - `canvas`: canvas 配置カード。
/// - `project`: project 概要カード。
/// - `projectMigration`: Web contract migrationカード。
/// - `designTokens`: design token カード。
/// - `iconCDN`: icon CDN 依存性カード。
/// - `localeResource`: locale resource カード。
/// - `resourcePath`: project resource path カード。
enum InspectorSectionID: String, Hashable, CaseIterable {
    case context
    case component
    case pages
    case alignment
    case layout
    case position
    case dimensions
    case appearance
    case text
    case typography
    case media
    case icon
    case effects
    case animation
    case scrollTimeline
    case htmlDocument
    case i18nRuntime
    case localeTypography
    case mockState
    case canvas
    case project
    case projectMigration
    case designTokens
    case iconCDN
    case localeResource
    case resourcePath

    /// 論理名（日本語）: CSS宣言対応セクション取得関数
    /// 処理概要: CSS property または OpenGraphite custom property 名から、Inspector 上で開くべきカードを返します。
    ///
    /// - Parameter key: CSS property または OpenGraphite 予約 custom property 名。
    /// - Returns: 関連する Inspector セクション ID。未対応の場合は空集合。
    static func sections(forCSSKey key: String) -> Set<InspectorSectionID> {
        switch key {
        case "align-items", "justify-content":
            return [.alignment]
        case "display", "flex-direction", "grid-template-columns", "grid-template-rows", "grid-auto-flow",
             "gap", "padding", "margin", "flex":
            return [.layout]
        case "visibility":
            return [.context, .layout]
        case "position", "left", "top", "right", "bottom", "z-index":
            return [.position]
        case "width", "height", "min-width", "min-height", "max-width":
            return [.dimensions]
        case "color", "background", "border", "border-radius":
            return [.appearance]
        case "font-family", "font-size", "font-weight", "line-height", "letter-spacing", "text-align", "overflow-wrap":
            return [.typography]
        case "object-fit":
            return [.media]
        case "stroke-width", "mask-image", "-webkit-mask-image":
            return [.icon]
        case "box-shadow", "transform-origin", "scale":
            return [.effects]
        case "animation-name", "animation-duration", "animation-delay",
             "animation-timing-function", "animation-iteration-count",
             "animation-fill-mode", "animation-direction",
             "animation-play-state", "animation":
            return [.animation]
        case "animation-timeline", "animation-range-start", "animation-range-end",
             "animation-range", "timeline-scope", "scroll-timeline-name",
             "scroll-timeline-axis", "scroll-timeline", "view-timeline-name",
             "view-timeline-axis", "view-timeline":
            return [.scrollTimeline]
        default:
            return []
        }
    }

    /// 論理名（日本語）: 複数CSS宣言対応セクション取得関数
    /// 処理概要: 複数 CSS key に対応する Inspector セクションを重複なくまとめます。
    ///
    /// - Parameter keys: CSS property または OpenGraphite 予約 custom property 名の一覧。
    /// - Returns: 関連する Inspector セクション ID 集合。
    static func sections<S: Sequence>(forCSSKeys keys: S) -> Set<InspectorSectionID> where S.Element == String {
        keys.reduce(into: Set<InspectorSectionID>()) { result, key in
            result.formUnion(sections(forCSSKey: key))
        }
    }

    /// 論理名（日本語）: 属性対応セクション取得関数
    /// 処理概要: 永続属性名から、Inspector 上で開くべきカードを返します。
    ///
    /// - Parameter name: 標準HTML属性または維持対象`data-og-*`属性名。
    /// - Returns: 関連する Inspector セクション ID。未対応の場合は空集合。
    static func sections(forAttributeName name: String) -> Set<InspectorSectionID> {
        switch name {
        case "hidden", "role", "data-og-locked", "href", "target", "rel", "download",
             "value", "name", "type", "placeholder", "disabled", "checked", "selected", "aria-label":
            return [.context]
        case "src", "alt":
            return [.media]
        case "data-og-icon-library", "data-og-icon-name", "data-og-icon-source":
            return [.icon]
        default:
            return []
        }
    }

    /// 論理名（日本語）: HTML編集操作対応セクション取得関数
    /// 処理概要: Web preview 由来の object edit 操作から、Inspector 上で開くべきカードを返します。
    ///
    /// - Parameter operation: 保存に成功した HTML object edit 操作。
    /// - Returns: 関連する Inspector セクション ID 集合。
    static func sections(for operation: HTMLObjectEditOperation) -> Set<InspectorSectionID> {
        switch operation {
        case let .setCSSVariable(_, key, _, _):
            return sections(forCSSKey: key)
        case let .setCSSVariables(_, values, _):
            return sections(forCSSKeys: values.keys)
        case let .setAttribute(_, name, _, _, _):
            return sections(forAttributeName: name)
        case let .removeAttribute(_, name, _, _):
            return sections(forAttributeName: name)
        case .renameNodeID:
            return [.context]
        case .setIcon:
            return [.icon]
        case .setTextContent:
            return [.text]
        case .insertHTML, .replaceNodeHTML, .deleteNode, .moveNode:
            return []
        }
    }
}

/// 論理名（日本語）: インスペクターセクション開放要求
/// 概要: Preview 側編集で変更されたパラメータに対応する Inspector カードを one-shot で開く要求です。
///
/// プロパティ:
/// - `sequence`: 要求順序を表す単調増加番号。
/// - `scopeIdentifier`: 要求を発行した選択対象。異なる選択へ持ち越さないために使います。
/// - `sectionIDs`: 開く対象の Inspector セクション ID 集合。
struct InspectorSectionOpenRequest: Equatable {
    var sequence: Int
    var scopeIdentifier: String
    var sectionIDs: Set<InspectorSectionID>
}
