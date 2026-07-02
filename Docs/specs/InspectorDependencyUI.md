# Inspector Dependency UI

この文書は、Inspector section 内で標準編集 UI と追加依存性 UI を分離して実装するための仕様です。OSS contributor が i18n 以外の依存性を追加するときも、同じ構造で custom UI を追加できることを目的にします。

## Display Model

Inspector section は、編集対象そのものの標準カードと、検出された依存性ごとの条件付きカードを並べます。Text section の場合は HTML 本文または fallback を標準カードで常に扱い、locale JSON、CMS、design token、external runtime などの追加資源は dependency provider が必要な場合だけ別カードとして追加します。

同じ編集対象項目に対して依存性カードが存在する場合も、標準カードへ統合しません。HTML / CSS / `.ogp` / locale JSON / 外部 runtime のように正本が異なる値は、同じ section 内の別カードとして表示し、カード見出しと status で責務を明示します。

依存性カードは次の状態を共通 status として表します。

| Status | 意味 |
| --- | --- |
| `editable` | OpenGraphite から検出済み正本へ書き戻せる。 |
| `readOnly` | 正本は検出できるが、この画面から編集しない。 |
| `missing` | 依存資源や active context が不足している。保存時に作成できる場合もこの状態を使う。 |
| `notConfigured` | 依存性自体が未導入または未設定。 |
| `external` | 外部式、外部 service、未対応 runtime など OpenGraphite が所有しない。 |

## Directory Responsibilities

Inspector dependency UI は、共通 chrome、section 固有の registry、依存性固有 UI を分離します。

```text
App/Sources/Presentation/Inspector/
├── Core/
│   ├── InspectorDependencyCardModel.swift
│   ├── InspectorDependencyCard.swift
│   └── InspectorSection.swift
├── Text/
│   ├── InspectorTextDependencyRegistry.swift
│   ├── InspectorTextSectionModel.swift
│   ├── InspectorTextValueBlocks.swift
│   └── TextContentSection.swift
└── Dependencies/
    └── LocaleResource/
        └── LocaleResourceTextDependency.swift
```

- `Core/`: section をまたいで使う card chrome、status、pill、action、section frame だけを置く。特定依存性の判定や UI を置かない。
- `Text/`: Text section の標準カード、Text 用 dependency context、registry、render context を置く。i18n、CMS など特定 provider の UI を置かない。
- `Dependencies/<DependencyName>/`: 依存性ごとの provider、payload model、custom card view を置く。`LocaleResourceTextDependency` は locale JSON 用の実装例であり、i18n 専用の仕組みではない。

依存性固有の SwiftUI view は、原則としてその dependency directory の中で `private` に閉じます。section 側が知るのは provider ID、共通 card model、型消去された payload、render context だけです。

## Text Dependency Provider Contract

Text section に依存性 UI を追加する場合、`InspectorTextDependencyProvider` を実装して `InspectorTextDependencyRegistry.standard` へ登録します。

provider は次の責務を持ちます。

1. `makeModel(context:)` で依存性が対象 node に適用されるかを判定する。
2. 適用しない場合は `nil` を返す。
3. 適用する場合は `InspectorDependencyCardModel` と provider 固有 payload を `InspectorTextDependencyCardModel` に入れて返す。
4. `makeView(model:context:)` で payload を期待型に戻し、`InspectorDependencyCard` の中へ custom UI を描画する。

最小 skeleton は次の形です。

```swift
enum CMSContentTextDependency {
    static let providerID = "text.cms-content"

    static var provider: InspectorTextDependencyProvider {
        InspectorTextDependencyProvider(
            id: providerID,
            makeModel: makeModel,
            makeView: makeView
        )
    }

    private static func makeModel(
        context: InspectorTextDependencyContext
    ) -> InspectorTextDependencyCardModel? {
        guard context.node.textSource == "cms" else { return nil }

        let card = InspectorDependencyCardModel(
            id: "text-cms-content",
            title: "CMS Content",
            sourceLabel: "CMS",
            status: .external,
            detail: "This text is resolved by a CMS source.",
            action: nil
        )

        return InspectorTextDependencyCardModel(
            providerID: providerID,
            card: card,
            payload: CMSContentPayload(...)
        )
    }

    private static func makeView(
        model: InspectorTextDependencyCardModel,
        context: InspectorTextDependencyRenderContext
    ) -> AnyView {
        guard let payload = model.payload(as: CMSContentPayload.self) else {
            return AnyView(
                InspectorDependencyCard(model: model.card, onAction: context.handle) {
                    InspectorInfoRow(label: "provider", value: model.providerID)
                }
            )
        }

        return AnyView(
            CMSContentDependencyCard(
                card: model.card,
                payload: payload,
                renderContext: context
            )
        )
    }
}
```

登録は `InspectorTextDependencyRegistry.standard` に追加します。

```swift
static var standard: InspectorTextDependencyRegistry {
    InspectorTextDependencyRegistry(
        providers: [
            LocaleResourceTextDependency.provider,
            CMSContentTextDependency.provider
        ]
    )
}
```

provider ID は `<section>.<dependency>` 形式を基本にし、同じ section 内で一意にします。card ID は SwiftUI の差分更新に使われるため、依存性種類ごとに安定した値にします。

## Data And Mutation Boundaries

dependency provider は SwiftUI 表示を担当し、正本ファイルを直接書き換えません。永続化、preview cache 更新、validation、外部変更との調停は `EditorStore`、Agent Interface core、または既存の project/resource 操作へ委譲します。

Text dependency provider が参照できる入力は `InspectorTextDependencyContext` へ集約します。新しい依存性で Project 側の検出結果が必要な場合は、依存性固有の UI へ `EditorStore` 全体を渡して自由に探索させるのではなく、必要な snapshot を `InspectorProjectDependencySnapshot` などの section context に追加します。

custom UI から保存する場合は、次の順序を守ります。

1. 入力中の preview 反映が可能な値だけ app 内 cache へ反映する。
2. commit 時に `EditorStore` の専用操作を呼ぶ。
3. store 側で対象 node、page URL、旧値、locale などの期待条件を確認する。
4. 永続化に成功した場合だけ確定値として扱う。

外部 service や未対応 runtime の値は `.external` または `.readOnly` にして、表示や navigation action に留めます。依存性の導入、認証、外部 API 呼び出しを Inspector card 内へ直接埋め込まないでください。

## Adding A New Dependency UI

Text section に依存性 UI を追加する手順は次の通りです。

1. 依存性の正本を決める。
   - HTML fallback、locale JSON、remote CMS、CSS token など、保存先と所有範囲を明確にする。
2. 検出結果を app state に追加する。
   - HTML / script / resource の検出は Agent Interface core または store の既存同期経路へ置く。
   - UI が必要とする最小情報だけを section context へ渡す。
3. `App/Sources/Presentation/Inspector/Dependencies/<DependencyName>/` を作る。
   - `<DependencyName>TextDependency.swift` に payload model、provider、custom card view を置く。
4. `makeModel(context:)` を実装する。
   - 対象外なら必ず `nil` を返す。
   - 共通状態は `InspectorDependencyStatus` に変換する。
   - Project resource へ移動できる場合は `InspectorDependencyCardAction` を付ける。
5. `makeView(model:context:)` を実装する。
   - `InspectorDependencyCard` を使って共通 chrome を保持する。
   - payload 型が違う場合は provider ID を表示する fallback を返す。
6. `InspectorTextDependencyRegistry.standard` へ provider を登録する。
7. `Tests/OpenGraphiteTests/Presentation/InspectorTextSectionModel_test.swift` と store / core の該当テストを追加する。
8. `./Scripts/quality_gate.sh` を完走させる。

依存性 UI が他の section に必要な場合は、Text の registry を流用せず、対象 section 用に同じ構造を作ります。

```text
App/Sources/Presentation/Inspector/<Section>/
├── Inspector<Section>DependencyRegistry.swift
├── Inspector<Section>SectionModel.swift
└── <Section>ContentSection.swift
```

section 固有 context と render context を定義し、dependency directory 側に `<DependencyName><Section>Dependency.swift` を追加します。`Core/` に置けるのは section をまたいで意味が変わらない card chrome と status だけです。

## Testing Requirements

依存性 UI を追加または変更した場合は、少なくとも次をテストします。

- 対象外 node では dependency card が表示されない。
- 対象 node では標準カードと dependency card が同じ section 内に分離して表示モデル化される。
- `editable`、`missing`、`notConfigured`、`external` など主要 status が正しく選ばれる。
- custom provider を registry に追加しても section model の既存実装を改造せず card を追加できる。
- payload が view で期待型に戻せる。
- 保存可能な依存性では、store/core が正しい正本へ保存し、preview cache と永続 resource の境界を壊さない。

UI 目視確認が必要な変更では、アプリを起動して Inspector section のカード分離、status pill、picker、編集欄、read-only 表示が重ならないことを確認します。
