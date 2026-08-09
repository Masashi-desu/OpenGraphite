import Testing
@testable import OpenGraphite

/// 論理名（日本語）: インスペクター整列モデル関連のテストスイート
/// 概要: computed `display` / `flex-direction`由来のlayoutから軸、適用可否、WebKit実効値を解決できることを確認します。
@Suite("インスペクター整列モデル関連のテストスイート")
struct InspectorAlignmentModelTests {
    /// 論理名（日本語）: レイアウト方向判定テスト
    /// 概要: computed style由来のlayoutから縦並びとflex/grid整列の有効性を判定できることを検証します。
    @Test("computed layoutから並び方向と整列の有効性を判定できる")
    func testLayoutClassification() {
        // コンディション：flex縦横、grid、blockのlayout分類を用意する（Given）
        let verticalLayout = "vertical"
        let horizontalLayout = "horizontal"
        let gridLayout = "grid"
        let blockLayout = "block"

        // 検証内容：並び方向と整列の有効性を判定する（When）
        let isVertical = InspectorAlignmentModel.isVerticalLayout(verticalLayout)
        let isHorizontalVertical = InspectorAlignmentModel.isVerticalLayout(horizontalLayout)
        let supportsVerticalAlignment = InspectorAlignmentModel.supportsAlignment(verticalLayout)
        let supportsGridAlignment = InspectorAlignmentModel.supportsAlignment(gridLayout)
        let supportsBlockAlignment = InspectorAlignmentModel.supportsAlignment(blockLayout)

        // 期待値：verticalだけ縦並びで、flex/gridでは整列が効きblockでは無効になる（Then）
        #expect(isVertical)
        #expect(isHorizontalVertical == false)
        #expect(supportsVerticalAlignment)
        #expect(supportsGridAlignment)
        #expect(supportsBlockAlignment == false)
    }

    /// 論理名（日本語）: Computed整列値解決テスト
    /// 概要: authored未指定時にOpenGraphite独自既定ではなくWebKit computed値を表示することを検証します。
    @Test("未指定時はWebKit computed整列値を表示する")
    func testResolvedComputedValues() {
        // コンディション：authored値が未指定でcomputed値だけが解決された状態を用意する（Given）
        let unsetValue = ""

        // 検証内容：WebKit由来のalign-itemsとjustify-contentを実効値として解決する（When）
        let alignItems = InspectorAlignmentModel.resolvedAlignItems(unsetValue, computedValue: "normal")
        let justifyContent = InspectorAlignmentModel.resolvedJustifyContent(unsetValue, computedValue: "space-evenly")

        // 期待値：runtimeが実際に描画しているcomputed値をそのまま返す（Then）
        #expect(alignItems == "normal")
        #expect(justifyContent == "space-evenly")
    }

    /// 論理名（日本語）: 指定済み整列値保持テスト
    /// 概要: 明示指定がある場合は既定値で上書きされないことを検証します。
    @Test("明示指定がある場合は既定値で上書きされない")
    func testResolvedValuesKeepExplicitDeclarations() {
        // コンディション：align-items と justify-content に明示指定がある状態を用意する（Given）
        let alignItems = "flex-end"
        let justifyContent = "space-between"

        // 検証内容：実効値を解決する（When）
        let resolvedAlignItems = InspectorAlignmentModel.resolvedAlignItems(alignItems, computedValue: "normal")
        let resolvedJustifyContent = InspectorAlignmentModel.resolvedJustifyContent(
            justifyContent,
            computedValue: "normal"
        )

        // 期待値：指定した値がそのまま返る（Then）
        #expect(resolvedAlignItems == "flex-end")
        #expect(resolvedJustifyContent == "space-between")
    }

    /// 論理名（日本語）: 整列軸選択肢方向テスト
    /// 概要: 並び方向に応じて主軸と交差軸の選択肢アイコンが入れ替わることを検証します。
    @Test("並び方向に応じて主軸と交差軸の選択肢が入れ替わる")
    func testAxisOptionsFollowLayoutDirection() {
        // コンディション：縦並びと横並びのそれぞれで選択肢を組み立てる（Given）
        let verticalMainOptions = InspectorAlignmentAxisOptions.mainAxisOptions(isVerticalLayout: true)
        let horizontalMainOptions = InspectorAlignmentAxisOptions.mainAxisOptions(isVerticalLayout: false)
        let verticalCrossOptions = InspectorAlignmentAxisOptions.crossAxisOptions(isVerticalLayout: true)

        // 検証内容：先頭の選択肢の値とラベルを確認する（When）
        let verticalMainStartLabel = verticalMainOptions.first?.label
        let horizontalMainStartLabel = horizontalMainOptions.first?.label
        let crossOptionValues = verticalCrossOptions.map(\.value)

        // 期待値：主軸の開始側は縦並びで上寄せ、横並びで左寄せになり、交差軸には stretch が含まれる（Then）
        #expect(verticalMainStartLabel == "上寄せ")
        #expect(horizontalMainStartLabel == "左寄せ")
        #expect(crossOptionValues.contains("stretch"))
        #expect(verticalMainOptions.map(\.value).contains("space-between"))
    }
}
