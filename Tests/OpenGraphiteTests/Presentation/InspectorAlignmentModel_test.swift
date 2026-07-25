import Testing
@testable import OpenGraphite

/// 論理名（日本語）: インスペクター整列モデル関連のテストスイート
/// 概要: `data-og-layout` から主軸と交差軸の対応、整列の有効性、既定値の補完が解決できることを確認します。
@Suite("インスペクター整列モデル関連のテストスイート")
struct InspectorAlignmentModelTests {
    /// 論理名（日本語）: レイアウト方向判定テスト
    /// 概要: `data-og-layout` から縦並びかどうかと整列の有効性を判定できることを検証します。
    @Test("layout値から並び方向と整列の有効性を判定できる")
    func testLayoutClassification() {
        // コンディション：3 種類の layout 値を用意する（Given）
        let verticalLayout = "vertical"
        let horizontalLayout = "horizontal"
        let absoluteLayout = "absolute"

        // 検証内容：並び方向と整列の有効性を判定する（When）
        let isVertical = InspectorAlignmentModel.isVerticalLayout(verticalLayout)
        let isHorizontalVertical = InspectorAlignmentModel.isVerticalLayout(horizontalLayout)
        let supportsVerticalAlignment = InspectorAlignmentModel.supportsAlignment(verticalLayout)
        let supportsAbsoluteAlignment = InspectorAlignmentModel.supportsAlignment(absoluteLayout)

        // 期待値：vertical だけ縦並びで、absolute は整列が効かない（Then）
        #expect(isVertical)
        #expect(isHorizontalVertical == false)
        #expect(supportsVerticalAlignment)
        #expect(supportsAbsoluteAlignment == false)
    }

    /// 論理名（日本語）: 既定整列値解決テスト
    /// 概要: 未指定時に OpenGraphite.css の既定値が補われることを検証します。
    @Test("未指定時はOpenGraphite.cssの既定整列値が補われる")
    func testResolvedDefaults() {
        // コンディション：align-items と justify-content が未指定の状態を用意する（Given）
        let unsetValue = ""

        // 検証内容：縦並びと横並びで実効値を解決する（When）
        let verticalAlignItems = InspectorAlignmentModel.resolvedAlignItems(unsetValue, layout: "vertical")
        let horizontalAlignItems = InspectorAlignmentModel.resolvedAlignItems(unsetValue, layout: "horizontal")
        let justifyContent = InspectorAlignmentModel.resolvedJustifyContent(unsetValue)

        // 期待値：縦並びは stretch、横並びは center、主軸は flex-start になる（Then）
        #expect(verticalAlignItems == "stretch")
        #expect(horizontalAlignItems == "center")
        #expect(justifyContent == "flex-start")
    }

    /// 論理名（日本語）: 指定済み整列値保持テスト
    /// 概要: 明示指定がある場合は既定値で上書きされないことを検証します。
    @Test("明示指定がある場合は既定値で上書きされない")
    func testResolvedValuesKeepExplicitDeclarations() {
        // コンディション：align-items と justify-content に明示指定がある状態を用意する（Given）
        let alignItems = "flex-end"
        let justifyContent = "space-between"

        // 検証内容：実効値を解決する（When）
        let resolvedAlignItems = InspectorAlignmentModel.resolvedAlignItems(alignItems, layout: "vertical")
        let resolvedJustifyContent = InspectorAlignmentModel.resolvedJustifyContent(justifyContent)

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
