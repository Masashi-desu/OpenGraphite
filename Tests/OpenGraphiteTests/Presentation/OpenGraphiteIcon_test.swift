import Testing
@testable import OpenGraphite

/// 論理名（日本語）: OpenGraphiteアイコン関連のテストスイート
/// 概要: Lucide と SF Symbols を同じアイコン記述子で扱うための基本契約を確認します。
@Suite("OpenGraphiteアイコン関連のテストスイート")
struct OpenGraphiteIconTests {
    /// 論理名（日本語）: 選択可能アイコンライブラリテスト
    /// 概要: Asset Panel から Lucide と SF Symbols を選択できるライブラリ一覧であることを検証します。
    @Test("LucideとSF Symbolsを選択可能にする")
    func testSelectableLibrariesIncludeLucideAndSystemSymbols() {
        // コンディション：アイコンライブラリの選択肢を取得する（Given）
        let libraries = OpenGraphiteIconLibrary.selectableLibraries

        // 検証内容：選択肢の表示名と既定値を確認する（When）
        let titles = libraries.map(\.title)

        // 期待値：Lucide と SF Symbols が選べ、既定値は Lucide になる（Then）
        #expect(libraries == [.lucide, .systemSymbols])
        #expect(titles == ["Lucide", "SF Symbols"])
        #expect(OpenGraphiteIconLibrary.defaultLibrary == .lucide)
    }

    /// 論理名（日本語）: SF Symbolsアイコン記述子テスト
    /// 概要: SF Symbols 名が共通アイコン記述子として保持されることを検証します。
    @Test("SF Symbolsアイコン記述子を作れる")
    func testSystemIconDescriptorUsesSystemSymbolsLibrary() {
        // コンディション：SF Symbols 名からアイコン記述子を作成する（Given）
        let icon = OpenGraphiteIcon.system("folder")

        // 検証内容：供給元と fallback を確認する（When）
        let library = icon.library

        // 期待値：供給元と fallback の両方が SF Symbols 名を指す（Then）
        #expect(library == .systemSymbols)
        #expect(icon.name == "folder")
        #expect(icon.fallbackSystemName == "folder")
    }

    /// 論理名（日本語）: Lucideアイコン記述子テスト
    /// 概要: Lucide の icon ID と SF Symbols fallback が同じ記述子に保持されることを検証します。
    @Test("Lucideアイコン記述子にSF Symbols fallbackを持てる")
    func testLucideIconDescriptorKeepsFallbackSystemSymbol() {
        // コンディション：Lucide ID と SF Symbols fallback からアイコン記述子を作成する（Given）
        let icon = OpenGraphiteIcon.lucide("package", fallbackSystemName: "shippingbox")

        // 検証内容：供給元と fallback を確認する（When）
        let library = icon.library

        // 期待値：Lucide を優先しつつ SF Symbols fallback を保持する（Then）
        #expect(library == .lucide)
        #expect(icon.name == "package")
        #expect(icon.fallbackSystemName == "shippingbox")
    }

    /// 論理名（日本語）: 左カラムアイコン割り当てテスト
    /// 概要: Layers と HTML カードのアイコンが OpenGraphite の source-of-truth 思想に沿うことを検証します。
    @Test("左カラムのアイコンを実装とデザインの工程に沿わせる")
    func testLeftColumnIconsFollowSourceOfTruthMeaning() {
        // コンディション：左カラムで使う代表的なアイコン記述子を取得する（Given）
        let frameIcon = OpenGraphiteIcon.layerType("frame")
        let pageIcon = OpenGraphiteIcon.pageDocument
        let componentIcon = OpenGraphiteIcon.componentDocument
        let collectionIcon = OpenGraphiteIcon.collectionGroup

        // 検証内容：Lucide ID の割り当てを確認する（When）
        let iconNames = [
            frameIcon.name,
            pageIcon.name,
            componentIcon.name,
            collectionIcon.name
        ]

        // 期待値：frame は code、HTML page は file-code、component 系は component / blocks になる（Then）
        #expect(iconNames == ["code", "file-code", "component", "blocks"])
        #expect(frameIcon.fallbackSystemName == "chevron.left.forwardslash.chevron.right")
    }
}
