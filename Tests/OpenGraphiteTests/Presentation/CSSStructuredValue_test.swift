import Testing
@testable import OpenGraphite

/// 論理名（日本語）: CSS構造化値関連のテストスイート
/// 概要: Inspector の構造化 UI が使う CSS shorthand、関数値、複合値の round-trip を検証します。
@Suite("CSS構造化値関連のテストスイート")
struct CSSStructuredValueTests {
    /// 論理名（日本語）: CSS四辺shorthand解析テスト
    /// 概要: padding などの 2 値 shorthand を四辺へ分解し、同じ shorthand へ戻せることを検証します。
    @Test("2値shorthandを四辺へ展開して再直列化できる")
    func testBoxShorthandRoundTrip() {
        // コンディション：上下と左右を持つ padding shorthand を用意する
        let value = CSSBoxValue(cssString: "14px 20px")

        // 検証内容：四辺の値と再直列化結果を確認する
        let cssString = value.cssString

        // 期待値：上下左右へ展開され、保存時は標準 shorthand に戻る
        #expect(value.top == "14px")
        #expect(value.right == "20px")
        #expect(value.bottom == "14px")
        #expect(value.left == "20px")
        #expect(cssString == "14px 20px")
    }

    /// 論理名（日本語）: CSS四辺値編集対象外テスト
    /// 概要: `calc()` を含む shorthand を通常 UI で編集せず、元の CSS 値を保持することを検証します。
    @Test("通常UI未対応の四辺値は編集対象外として保持する")
    func testUnsupportedBoxValueIsReadOnly() {
        // コンディション：通常 UI では 1 入力欄へ落とし込まない calc() 入り padding 値を用意する
        let value = CSSBoxValue(cssString: "calc(100% - 24px) 20px")

        // 検証内容：対応可否と再直列化結果を確認する
        let cssString = value.cssString

        // 期待値：編集対象外として扱われ、元の CSS 値は維持される
        #expect(value.isSupported == false)
        #expect(value.unsupportedValue == "calc(100% - 24px) 20px")
        #expect(cssString == "calc(100% - 24px) 20px")
    }

    /// 論理名（日本語）: CSS関数寸法値解析テスト
    /// 概要: `min()` のような CSS 関数値を通常 UI の関数モードとして扱えることを検証します。
    @Test("min関数寸法値を解析して保持できる")
    func testDimensionFunctionRoundTrip() {
        // コンディション：サンプルで使われる min() の width 値を用意する
        let value = CSSDimensionValue(cssString: "min(100%,560px)")

        // 検証内容：関数名、引数、再直列化結果を確認する
        let cssString = value.cssString

        // 期待値：関数モードとして分解され、CSS 値へ戻せる
        #expect(value.kind == .function)
        #expect(value.functionName == "min")
        #expect(value.arguments == ["100%", "560px"])
        #expect(cssString == "min(100%,560px)")
    }

    /// 論理名（日本語）: CSS寸法値編集対象外テスト
    /// 概要: `calc()` のような通常 UI 未対応値を編集対象外として分類し、元の CSS 値を保持することを検証します。
    @Test("通常UI未対応の寸法値は編集対象外として保持する")
    func testUnsupportedDimensionValueIsReadOnly() {
        // コンディション：通常 UI では式として分解しない calc() の width 値を用意する
        let value = CSSDimensionValue(cssString: "calc(100% - 24px)")

        // 検証内容：分類と再直列化結果を確認する
        let cssString = value.cssString

        // 期待値：編集対象外として扱われ、元の CSS 値は維持される
        #expect(value.kind == .unsupported)
        #expect(value.unsupportedValue == "calc(100% - 24px)")
        #expect(cssString == "calc(100% - 24px)")
    }

    /// 論理名（日本語）: CSS数値単位値編集対象外テスト
    /// 概要: 外部 CSS 変数参照を通常 UI の数値欄として編集せず、元の CSS 値を保持することを検証します。
    @Test("通常UI未対応の数値単位値は編集対象外として保持する")
    func testUnsupportedNumericUnitValueIsReadOnly() {
        // コンディション：OpenGraphite.css の通常編集契約外にある CSS 変数参照を用意する
        let value = CSSNumericUnitValue(cssString: "var(--external-size)")

        // 検証内容：対応可否と再直列化結果を確認する
        let cssString = value.cssString

        // 期待値：編集対象外として扱われ、元の CSS 値は維持される
        #expect(value.isSupported == false)
        #expect(value.unsupportedValue == "var(--external-size)")
        #expect(cssString == "var(--external-size)")
    }

    /// 論理名（日本語）: CSS単位分離値解析テスト
    /// 概要: Inspector の入力欄へ出す値と外側へ出す単位を分離し、CSS token として復元できることを検証します。
    @Test("単位付きtokenを入力値と単位へ分離して復元できる")
    func testUnitSeparatedValueSplitsUnitToken() {
        // コンディション：px と % を含む単純 CSS token を用意する
        let pixelValue = CSSUnitSeparatedValue(cssString: "64px")
        let percentageValue = CSSUnitSeparatedValue(cssString: "50%")

        // 検証内容：入力欄用の値、外側表示用の単位、復元結果を確認する
        let pixelCSSString = pixelValue.cssString
        let percentageCSSString = percentageValue.cssString

        // 期待値：TextField に入る値から単位が除かれ、CSS 値としては元の単位が維持される
        #expect(pixelValue.fieldValue == "64")
        #expect(pixelValue.unit == "px")
        #expect(pixelCSSString == "64px")
        #expect(percentageValue.fieldValue == "50")
        #expect(percentageValue.unit == "%")
        #expect(percentageCSSString == "50%")
    }

    /// 論理名（日本語）: CSS単位分離値リテラル保持テスト
    /// 概要: keyword や関数値を誤って単位分離せず、元の CSS token として保持することを検証します。
    @Test("単位分離対象外のtokenはリテラルとして保持する")
    func testUnitSeparatedValueKeepsLiteralTokens() {
        // コンディション：単位付き数値ではない keyword と関数値を用意する
        let keywordValue = CSSUnitSeparatedValue(cssString: "auto")
        let functionValue = CSSUnitSeparatedValue(cssString: "min(100%,560px)")

        // 検証内容：分離判定と復元結果を確認する
        let keywordCSSString = keywordValue.cssString
        let functionCSSString = functionValue.cssString

        // 期待値：TextField に表示する値はリテラルのままで、単位は外側表示へ切り出されない
        #expect(keywordValue.isNumericLike == false)
        #expect(keywordValue.fieldValue == "auto")
        #expect(keywordValue.unit == "")
        #expect(keywordCSSString == "auto")
        #expect(functionValue.isNumericLike == false)
        #expect(functionValue.fieldValue == "min(100%,560px)")
        #expect(functionValue.unit == "")
        #expect(functionCSSString == "min(100%,560px)")
    }

    /// 論理名（日本語）: CSS clamp 関数寸法値解析テスト
    /// 概要: `clamp()` の 3 引数を個別に保持し、同じ CSS 値へ戻せることを検証します。
    @Test("clamp関数寸法値を3引数として保持できる")
    func testDimensionClampFunctionRoundTrip() {
        // コンディション：最小値、推奨値、最大値を持つ clamp() の width 値を用意する
        let value = CSSDimensionValue(cssString: "clamp(320px,50vw,620px)")

        // 検証内容：関数名、引数、表示ラベル、再直列化結果を確認する
        let cssString = value.cssString

        // 期待値：3 つの引数が個別に保持され、CSS 値へ戻る
        #expect(value.kind == .function)
        #expect(value.functionName == "clamp")
        #expect(value.arguments == ["320px", "50vw", "620px"])
        #expect(value.functionArgumentLabels == ["Min", "Preferred", "Max"])
        #expect(cssString == "clamp(320px,50vw,620px)")
    }

    /// 論理名（日本語）: 空寸法値直列化テスト
    /// 概要: length モードで数値が空の場合、単位だけの CSS 値を保存しないことを検証します。
    @Test("寸法値の数値が空なら単位だけを直列化しない")
    func testDimensionLengthWithoutPrimaryDoesNotSerializeUnitOnly() {
        // コンディション：単位はあるが数値が空の length 寸法値を用意する
        var value = CSSDimensionValue(cssString: "")
        value.kind = .length
        value.primary = ""
        value.unit = "px"

        // 検証内容：CSS 文字列へ直列化する
        let cssString = value.cssString

        // 期待値：`px` だけでは保存されず、未設定として扱われる
        #expect(cssString == "")
    }

    /// 論理名（日本語）: CSS線形グラデーション解析テスト
    /// 概要: linear-gradient の角度と stop を分解し、既存値の構造を保持できることを検証します。
    @Test("linear-gradientを角度とstopへ分解できる")
    func testLinearGradientRoundTrip() throws {
        // コンディション：サンプルで使われる linear-gradient 値を用意する
        let gradient = try #require(
            CSSLinearGradientValue(cssString: "linear-gradient(135deg,#ffffff 0%,#e9fbf5 54%,#fff3d6 100%)")
        )

        // 検証内容：角度、stop、再直列化結果を確認する
        let cssString = gradient.cssString

        // 期待値：複数 stop が色と位置に分離され、標準 CSS 関数へ戻る
        #expect(gradient.angle == "135deg")
        #expect(gradient.stops.map(\.color) == ["#ffffff", "#e9fbf5", "#fff3d6"])
        #expect(gradient.stops.map(\.position) == ["0%", "54%", "100%"])
        #expect(cssString == "linear-gradient(135deg,#ffffff 0%,#e9fbf5 54%,#fff3d6 100%)")
    }

    /// 論理名（日本語）: CSS背景値編集対象外テスト
    /// 概要: 通常 UI 未対応の background 値を編集対象外として分類し、元の CSS 値を保持することを検証します。
    @Test("通常UI未対応の背景値は編集対象外として保持する")
    func testUnsupportedBackgroundValueIsReadOnly() {
        // コンディション：通常 UI では扱わない radial-gradient 値を用意する
        let value = CSSBackgroundValue(cssString: "radial-gradient(circle,#ffffff 0%,#000000 100%)")

        // 検証内容：分類と再直列化結果を確認する
        let cssString = value.cssString

        // 期待値：編集対象外として扱われ、元の CSS 値は維持される
        #expect(value.kind == .unsupported)
        #expect(value.unsupportedValue == "radial-gradient(circle,#ffffff 0%,#000000 100%)")
        #expect(cssString == "radial-gradient(circle,#ffffff 0%,#000000 100%)")
    }

    /// 論理名（日本語）: CSSグラデーション停止値編集対象外テスト
    /// 概要: 複数位置を持つ高度な color stop を通常 UI で編集せず、background 全体を保持することを検証します。
    @Test("高度なgradient stopは編集対象外として保持する")
    func testAdvancedGradientStopIsReadOnly() {
        // コンディション：1 stop に複数位置を持つ linear-gradient 値を用意する
        let value = CSSBackgroundValue(cssString: "linear-gradient(90deg,#ffffff 0% 40%,#000000 100%)")

        // 検証内容：分類と再直列化結果を確認する
        let cssString = value.cssString

        // 期待値：通常 UI の color / position 2 欄へ分解せず、編集対象外として保持する
        #expect(value.kind == .unsupported)
        #expect(value.unsupportedValue == "linear-gradient(90deg,#ffffff 0% 40%,#000000 100%)")
        #expect(cssString == "linear-gradient(90deg,#ffffff 0% 40%,#000000 100%)")
    }

    /// 論理名（日本語）: CSS罫線値解析テスト
    /// 概要: border shorthand を width、style、color に分解して再直列化できることを検証します。
    @Test("border shorthandを構造化できる")
    func testBorderRoundTrip() {
        // コンディション：一般的な border shorthand を用意する
        let value = CSSBorderValue(cssString: "1px solid rgba(34, 41, 49, 0.14)")

        // 検証内容：各要素と再直列化結果を確認する
        let cssString = value.cssString

        // 期待値：width、style、color が分離される
        #expect(value.width == "1px")
        #expect(value.style == "solid")
        #expect(value.color == "rgba(34, 41, 49, 0.14)")
        #expect(cssString == "1px solid rgba(34, 41, 49, 0.14)")
    }

    /// 論理名（日本語）: CSS shadow 解析テスト
    /// 概要: 単一 shadow を offset、blur、color に分解して再直列化できることを検証します。
    @Test("shadowを構造化できる")
    func testShadowRoundTrip() {
        // コンディション：一般的な box-shadow 値を用意する
        let value = CSSShadowValue(cssString: "0 18px 44px rgba(27, 34, 42, 0.08)")

        // 検証内容：各要素と再直列化結果を確認する
        let cssString = value.cssString

        // 期待値：offset、blur、color が分離される
        #expect(value.x == "0")
        #expect(value.y == "18px")
        #expect(value.blur == "44px")
        #expect(value.color == "rgba(27, 34, 42, 0.08)")
        #expect(cssString == "0 18px 44px rgba(27, 34, 42, 0.08)")
    }

    /// 論理名（日本語）: CSS shadow 編集対象外テスト
    /// 概要: 複数 shadow を通常 UI では編集せず、元の CSS 値を保持することを検証します。
    @Test("複数shadowは編集対象外として保持する")
    func testUnsupportedShadowValueIsReadOnly() {
        // コンディション：複数 layer を持つ box-shadow 値を用意する
        let value = CSSShadowValue(cssString: "0 1px 2px #000000, 0 8px 24px rgba(0, 0, 0, 0.2)")

        // 検証内容：対応可否と再直列化結果を確認する
        let cssString = value.cssString

        // 期待値：通常 UI の編集対象外として扱われ、元の CSS 値は維持される
        #expect(value.isSupported == false)
        #expect(value.unsupportedValue == "0 1px 2px #000000, 0 8px 24px rgba(0, 0, 0, 0.2)")
        #expect(cssString == "0 1px 2px #000000, 0 8px 24px rgba(0, 0, 0, 0.2)")
    }

    /// 論理名（日本語）: CSS flex 解析テスト
    /// 概要: flex shorthand を grow、shrink、basis に分けて保持できることを検証します。
    @Test("flex shorthandを構造化できる")
    func testFlexRoundTrip() {
        // コンディション：サンプルで使われる flex shorthand を用意する
        let value = CSSFlexValue(cssString: "1 1 0")

        // 検証内容：各要素と再直列化結果を確認する
        let cssString = value.cssString

        // 期待値：grow、shrink、basis が分離される
        #expect(value.grow == "1")
        #expect(value.shrink == "1")
        #expect(value.basis == "0")
        #expect(cssString == "1 1 0")
    }

    /// 論理名（日本語）: CSS flex 編集対象外テスト
    /// 概要: 外部 CSS 変数参照を通常 UI の flex 欄として編集せず、元の CSS 値を保持することを検証します。
    @Test("通常UI未対応のflex値は編集対象外として保持する")
    func testUnsupportedFlexValueIsReadOnly() {
        // コンディション：OpenGraphite.css の通常編集契約外にある CSS 変数参照を用意する
        let value = CSSFlexValue(cssString: "var(--external-flex)")

        // 検証内容：対応可否と再直列化結果を確認する
        let cssString = value.cssString

        // 期待値：編集対象外として扱われ、元の CSS 値は維持される
        #expect(value.isSupported == false)
        #expect(value.unsupportedValue == "var(--external-flex)")
        #expect(cssString == "var(--external-flex)")
    }
}
