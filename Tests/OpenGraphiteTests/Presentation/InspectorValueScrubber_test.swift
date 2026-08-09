import AppKit
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: インスペクター値スクラブ関連のテストスイート
/// 概要: Inspector の入力欄をドラッグしたときの数値変化、単位保持、修飾キーによる粒度切り替えを確認します。
@Suite("インスペクター値スクラブ関連のテストスイート")
struct InspectorValueScrubberTests {
    /// 論理名（日本語）: 単位保持スクラブテスト
    /// 概要: 単位付きの値をドラッグしたとき、単位を保ったまま数値だけが変わることを検証します。
    @Test("単位付きの値をドラッグすると単位を保ったまま数値が変わる")
    func testScrubKeepsUnit() {
        // コンディション：`24px` の入力欄を右へ 30pt ドラッグする（Given）
        let base = "24px"

        // 検証内容：既定粒度でスクラブ後の値を求める（When）
        let scrubbedValue = InspectorValueScrubber.scrubbed(base: base, translation: 30)

        // 期待値：3pt ごとに 1 ずつ増え、単位 px が保たれる（Then）
        #expect(scrubbedValue == "34px")
    }

    /// 論理名（日本語）: 未設定値スクラブテスト
    /// 概要: 未設定の入力欄をドラッグしたとき、補完単位付きの値が作られることを検証します。
    @Test("未設定の入力欄をドラッグすると補完単位付きの値になる")
    func testScrubFromEmptyValueUsesFallbackUnit() {
        // コンディション：未設定の入力欄を右へ 12pt ドラッグする（Given）
        let base = ""

        // 検証内容：補完単位 px でスクラブ後の値を求める（When）
        let scrubbedValue = InspectorValueScrubber.scrubbed(base: base, translation: 12, fallbackUnit: "px")

        // 期待値：0 を起点に 4 増えた値が px 付きで得られる（Then）
        #expect(scrubbedValue == "4px")
    }

    /// 論理名（日本語）: 未設定値の微小ドラッグ保持テスト
    /// 概要: 1 段階に満たないドラッグや負値不可方向のドラッグで、未設定値が `0px` に変わらないことを検証します。
    @Test("未設定値は有効な1段階が生じるまで変更されない")
    func testEmptyValueRemainsUnsetWithoutEffectiveStep() {
        // コンディション：未設定の負値不可入力欄を、1 段階未満または左方向へドラッグする（Given）
        let base = ""

        // 検証内容：微小ドラッグと負方向ドラッグの変換結果を求める（When）
        let tinyDragValue = InspectorValueScrubber.scrubbed(
            base: base,
            translation: 2,
            fallbackUnit: "px",
            allowsNegative: false
        )
        let negativeDragValue = InspectorValueScrubber.scrubbed(
            base: base,
            translation: -12,
            fallbackUnit: "px",
            allowsNegative: false
        )

        // 期待値：どちらも未設定のままで、意図しない `0px` を生成しない（Then）
        #expect(tinyDragValue == "")
        #expect(negativeDragValue == "")
    }

    /// 論理名（日本語）: 負値抑止スクラブテスト
    /// 概要: 負値を許可しない項目では 0 未満へ下がらないことを検証します。
    @Test("負値を許可しない項目は0未満にならない")
    func testScrubClampsNegativeValues() {
        // コンディション：`4px` の padding を左へ 60pt ドラッグする（Given）
        let base = "4px"

        // 検証内容：負値を許可しない設定でスクラブ後の値を求める（When）
        let scrubbedValue = InspectorValueScrubber.scrubbed(
            base: base,
            translation: -60,
            allowsNegative: false
        )

        // 期待値：0px で止まる（Then）
        #expect(scrubbedValue == "0px")
    }

    /// 論理名（日本語）: 修飾キー粒度テスト
    /// 概要: shift と option で 1 段階あたりの変化量が切り替わることを検証します。
    @Test("shiftで10倍、optionで1/10の粒度になる")
    func testScrubStepMultiplier() {
        // コンディション：`10px` の入力欄を右へ 30pt ドラッグする（Given）
        let base = "10px"

        // 検証内容：修飾キーごとにスクラブ後の値を求める（When）
        let shiftValue = InspectorValueScrubber.scrubbed(base: base, translation: 30, modifiers: .shift)
        let optionValue = InspectorValueScrubber.scrubbed(base: base, translation: 30, modifiers: .option)

        // 期待値：shift では 100 増え、option では 1 だけ増える（Then）
        #expect(shiftValue == "110px")
        #expect(optionValue == "11px")
    }

    /// 論理名（日本語）: スクラブ対象外値テスト
    /// 概要: 数値として扱えない CSS 値がドラッグ編集の対象外になることを検証します。
    @Test("数値として扱えない値はドラッグ編集の対象外になる")
    func testScrubRejectsNonNumericValues() {
        // コンディション：関数指定とキーワード指定を用意する（Given）
        let functionValue = "calc(100% - 20px)"
        let keywordValue = "auto"

        // 検証内容：スクラブ可否と変換結果を確認する（When）
        let isFunctionScrubbable = InspectorValueScrubber.isScrubbable(functionValue)
        let isKeywordScrubbable = InspectorValueScrubber.isScrubbable(keywordValue)
        let scrubbedFunctionValue = InspectorValueScrubber.scrubbed(base: functionValue, translation: 30)

        // 期待値：いずれもドラッグ編集の対象外で、値も変換されない（Then）
        #expect(isFunctionScrubbable == false)
        #expect(isKeywordScrubbable == false)
        #expect(scrubbedFunctionValue == nil)
    }

    /// 論理名（日本語）: 小数粒度スクラブテスト
    /// 概要: line-height のような小数粒度の項目で余分な桁が付かないことを検証します。
    @Test("小数粒度の項目でも余分な桁が付かない")
    func testScrubFormatsFractionalValues() {
        // コンディション：`1.5` の line-height を右へ 12pt ドラッグする（Given）
        let base = "1.5"

        // 検証内容：0.05 粒度でスクラブ後の値を求める（When）
        let scrubbedValue = InspectorValueScrubber.scrubbed(base: base, translation: 12, step: 0.05)

        // 期待値：0.2 増えた 1.7 が余分な 0 なしで得られる（Then）
        #expect(scrubbedValue == "1.7")
    }

    /// 論理名（日本語）: CSSプロパティ別スクラブ設定テスト
    /// 概要: property ごとに適した粒度と負値許可が選ばれることを検証します。
    @Test("CSSプロパティごとに適した粒度と負値許可が選ばれる")
    func testScrubProfileForCSSKey() {
        // コンディション：粒度が異なる代表的な property を用意する（Given）
        let paddingProfile = InspectorScrubProfile.forCSSKey("padding")
        let marginProfile = InspectorScrubProfile.forCSSKey("margin")
        let lineHeightProfile = InspectorScrubProfile.forCSSKey("line-height")
        let transformOriginProfile = InspectorScrubProfile.forCSSKey("transform-origin")
        let scaleProfile = InspectorScrubProfile.forCSSKey("scale")
        let zIndexProfile = InspectorScrubProfile.forCSSKey("z-index")

        // 検証内容：解決された設定を確認する（When）
        let paddingAllowsNegative = paddingProfile.allowsNegative
        let marginAllowsNegative = marginProfile.allowsNegative
        let lineHeightStep = lineHeightProfile.step
        let transformOriginAllowsNegative = transformOriginProfile.allowsNegative
        let scaleStep = scaleProfile.step
        let scaleFallbackUnit = scaleProfile.fallbackUnit
        let zIndexFallbackUnit = zIndexProfile.fallbackUnit

        // 期待値：padding は負値不可、margin と transform-origin は負値可、line-height は小数粒度、z-index は単位なし（Then）
        #expect(paddingAllowsNegative == false)
        #expect(marginAllowsNegative)
        #expect(lineHeightStep == 0.05)
        #expect(transformOriginAllowsNegative)
        #expect(scaleStep == 0.05)
        #expect(scaleFallbackUnit.isEmpty)
        #expect(zIndexFallbackUnit.isEmpty)
    }
}
