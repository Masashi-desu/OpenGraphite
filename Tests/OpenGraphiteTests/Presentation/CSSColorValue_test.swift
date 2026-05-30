import Testing
@testable import OpenGraphite

/// 論理名（日本語）: CSS色値関連のテストスイート
/// 概要: Inspector の色編集で使う CSS 色文字列の解析と HEX 変換を検証します。
@Suite("CSS色値関連のテストスイート")
struct CSSColorValueTests {
    /// 論理名（日本語）: HEX色解析テスト
    /// 概要: 6 桁 HEX 色を CSS 色値として解析し、標準 HEX 表記へ変換できることを検証します。
    @Test("6桁HEX色を解析できる")
    func testParsesSixDigitHexColor() {
        // コンディション：6 桁 HEX の CSS 色文字列を用意する
        let color = CSSColorValue(cssString: "#0f9f8f")

        // 検証内容：CSS 色値を HEX 文字列へ変換する
        let hexString = color?.cssHexString

        // 期待値：標準化された 6 桁 HEX 表記になる
        #expect(hexString == "#0F9F8F")
    }

    /// 論理名（日本語）: RGBA色解析テスト
    /// 概要: rgba() の alpha 値を含む CSS 色を 8 桁 HEX 表記へ変換できることを検証します。
    @Test("rgba色を8桁HEXへ変換できる")
    func testParsesRGBAColor() {
        // コンディション：alpha を含む rgba() の CSS 色文字列を用意する
        let color = CSSColorValue(cssString: "rgba(255, 255, 255, 0.72)")

        // 検証内容：CSS 色値を HEX 文字列へ変換する
        let hexString = color?.cssHexString

        // 期待値：alpha を含む 8 桁 HEX 表記になる
        #expect(hexString == "#FFFFFFB8")
    }

    /// 論理名（日本語）: 非単色CSS値拒否テスト
    /// 概要: gradient のような ColorPicker で直接扱わない CSS 値を色値として解釈しないことを検証します。
    @Test("gradientは単色として解析しない")
    func testRejectsGradientValue() {
        // コンディション：gradient の CSS 背景値を用意する
        let color = CSSColorValue(cssString: "linear-gradient(135deg,#ffffff 0%,#e9fbf5 54%,#fff3d6 100%)")

        // 検証内容：CSS 色値として解析する
        let isParsed = color != nil

        // 期待値：単色ではないため nil になる
        #expect(isParsed == false)
    }
}
