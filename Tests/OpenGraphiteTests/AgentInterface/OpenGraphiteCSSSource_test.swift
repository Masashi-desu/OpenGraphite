import Foundation
import Testing
import WebKit
@testable import OpenGraphite

/// 論理名（日本語）: CSS source・cascade関連のテストスイート
/// 概要: lossless parse、selector、cascade、inheritance、custom property、shorthand、media、最小差分を検証します。
@Suite("CSS source・cascade関連のテストスイート")
struct OpenGraphiteCSSSourceTests {
    /// 論理名（日本語）: CSS無編集roundtripテスト
    /// 概要: comment、未知at-rule、未知declarationを含むsourceがbyte単位で保持されることを確認します。
    @Test("無編集CSSは未知ruleとcommentを含めてbyte保持する")
    func testLosslessRoundtripPreservesUnknownRulesAndComments() {
        // コンディション：comment、未知at-rule、data URL、未知declarationを含むCSSがある（Given）
        let source = """
        /* keep-before */
        @future-theme dark {
          .card { future-property: fn(1; 2); }
        }
        .card, article[data-kind="hero"] {
          background: url("data:image/svg+xml;a;b"); /* keep-inline */
          unknown-property: calc(100% - 2px);
        }
        """

        // 検証内容：lossless CSS source文書として解析する（When）
        let document = OpenGraphiteCSSSourceDocument.parse(source)

        // 期待値：sourceはbyte相当のString一致で保持され、既知style ruleだけが索引化される（Then）
        #expect(document.source == source)
        #expect(document.rules.count == 1)
        #expect(document.rules[0].declarations.map(\.name) == ["background", "unknown-property"])
    }

    /// 論理名（日本語）: CSS selector cascadeテスト
    /// 概要: selector list、descendant/child、specificity、source order、importantの優先順位を確認します。
    @Test("selectorとspecificityとimportantを標準cascade順で評価する")
    func testSelectorSpecificitySourceOrderAndImportant() {
        // コンディション：type/class/id/attribute selectorとimportantが競合するCSSがある（Given）
        let source = """
        article .title { color: black; }
        article > h1.title[data-state="ready"] { color: blue; }
        #headline { color: green; }
        h1.title { color: purple !important; }
        """
        let article = OpenGraphiteCSSDOMElement(tagName: "article", attributes: ["class": "content"])
        let element = OpenGraphiteCSSDOMElement(
            tagName: "h1",
            attributes: ["id": "headline", "class": "title", "data-state": "ready"],
            ancestors: [article]
        )

        // 検証内容：対象elementのcascade traceを作成する（When）
        let trace = OpenGraphiteCSSSourceDocument.parse(source).cascadeTrace(for: element)

        // 期待値：important declarationがID selectorより優先され、全候補のprovenanceが残る（Then）
        #expect(trace.authoredValues["color"] == "purple")
        #expect(trace.winners["color"]?.selector == "h1.title")
        #expect(trace.candidates["color"]?.count == 4)
    }

    /// 論理名（日本語）: CSS selector comment tokenテスト
    /// 概要: selector comment内のcomma、whitespace、child combinatorを構文境界にせず、authored selectorを保持します。
    @Test("selector comment内のlistとcombinator文字はtoken境界にならない")
    func testSelectorCommentsDoNotCreateListOrCombinatorBoundaries() throws {
        // コンディション：comma、space、child combinatorを含むcommentがclass selector末尾にあるCSSがある（Given）
        let source = ".card/* keep, > */ { color: red; }\n"
        let element = OpenGraphiteCSSDOMElement(tagName: "article", attributes: ["class": "card"])

        // 検証内容：lossless parserでselector list、specificity、cascadeを評価する（When）
        let document = OpenGraphiteCSSSourceDocument.parse(source)
        let rule = try #require(document.rules.first)
        let trace = document.cascadeTrace(for: element)

        // 期待値：commentは1 selectorの非semantic tokenとなり、class ruleが一致してauthored bytesも保持される（Then）
        #expect(document.rules.count == 1)
        #expect(rule.selectorText == ".card/* keep, > */")
        #expect(rule.selectors == [".card/* keep, > */"])
        #expect(OpenGraphiteCSSSelector.specificity(of: rule.selectorText) ==
            OpenGraphiteCSSSpecificity(ids: 0, classes: 1, types: 0))
        #expect(trace.authoredValues["color"] == "red")
        #expect(trace.winners["color"]?.selector == ".card/* keep, > */")
        #expect(document.source == source)
    }

    /// 論理名（日本語）: Escaped attribute selector modifierテスト
    /// 概要: attribute名・値のCSS escapeを復号し、`i`と`s` modifierを標準の比較規則で評価します。
    @Test("escaped attribute selectorはiとs modifierをsemantic値へ適用する")
    func testEscapedAttributeSelectorsApplyCaseSensitivityModifiers() throws {
        // コンディション：escaped name/valueを持つASCII-insensitiveとcase-sensitiveのattribute selectorがある（Given）
        let source = #"""
        [data\2d label="a\+b" i] { color: red; }
        [data\2d label="a\+b" s] { background-color: blue; }
        [data-label^="A+" s] { border-color: green; }
        [data-label$="b" i] { outline-color: black; }
        """#
        let element = OpenGraphiteCSSDOMElement(
            tagName: "article",
            attributes: ["data-label": "A+B"]
        )

        // 検証内容：全attribute selectorを索引化して同じDOM attributeへcascade評価する（When）
        let document = OpenGraphiteCSSSourceDocument.parse(source)
        let trace = document.cascadeTrace(for: element)
        let firstRule = try #require(document.rules.first)

        // 期待値：i selectorと明示一致するs selectorだけが適用され、raw selector spellingとsource bytesが保持される（Then）
        #expect(document.rules.count == 4)
        #expect(firstRule.selectorText == #"[data\2d label="a\+b" i]"#)
        #expect(trace.authoredValues["color"] == "red")
        #expect(trace.authoredValues["background-color"] == nil)
        #expect(trace.authoredValues["border-color"] == "green")
        #expect(trace.authoredValues["outline-color"] == "black")
        #expect(trace.winners["color"]?.selector == #"[data\2d label="a\+b" i]"#)
        #expect(document.source == source)
    }

    /// 論理名（日本語）: CSS custom property継承解決テスト
    /// 概要: inherited custom propertyとfallbackを`var()`から解決することを確認します。
    @Test("custom propertyを継承してvar参照を解決する")
    func testCustomPropertyInheritanceAndResolution() {
        // コンディション：親からdesign tokenを継承し、子ruleがvar fallback付きで参照する（Given）
        let source = ".label { color: var(--color-copy, black); border-color: var(--missing, currentColor); }"
        let element = OpenGraphiteCSSDOMElement(tagName: "span", attributes: ["class": "label"])

        // 検証内容：親computed valueを渡してcascadeを評価する（When）
        let trace = OpenGraphiteCSSSourceDocument.parse(source).cascadeTrace(
            for: element,
            inheritedValues: ["--color-copy": "rgb(10, 20, 30)", "font-family": "Inter"]
        )

        // 期待値：custom propertyと通常の継承propertyが残り、varは実値またはfallbackへ解決される（Then）
        #expect(trace.resolvedValues["color"] == "rgb(10, 20, 30)")
        #expect(trace.resolvedValues["border-color"] == "currentColor")
        #expect(trace.resolvedValues["font-family"] == "Inter")
    }

    /// 論理名（日本語）: 未解決CSS custom property診断テスト
    /// 概要: fallbackを持たない未解決`var()`をcomputed値に誤採用せず、authored provenanceと不完全性を保持します。
    @Test("未解決var参照はcomputed値にせずauthored provenanceを保持する")
    func testUnresolvedCustomPropertyReferenceIsPreserved() {
        // コンディション：別resourceで解決され得るcustom property参照だけを持つruleがある（Given）
        let source = ".card { color: var(--external-color); }"
        let element = OpenGraphiteCSSDOMElement(tagName: "article", attributes: ["class": "card"])

        // 検証内容：local sourceだけでcascadeを評価する（When）
        let trace = OpenGraphiteCSSSourceDocument.parse(source).cascadeTrace(for: element)

        // 期待値：authored winnerは保持し、環境依存initialを捏造せずproperty単位で不完全とする（Then）
        #expect(trace.authoredValues["color"] == "var(--external-color)")
        #expect(trace.resolvedValues["color"] == nil)
        #expect(trace.incompleteProperties.contains("color"))
    }

    /// 論理名（日本語）: Multi-stylesheet custom property最終解決テスト
    /// 概要: stylesheet単体の暫定var解決ではなく、合成candidateと親継承値を揃えた後だけ不完全性を確定します。
    @Test("multi stylesheetは親custom property継承後に未解決flagを確定する")
    func testMultiStylesheetCustomPropertyResolutionUsesFinalInheritance() {
        // コンディション：子ruleだけの独立stylesheetと、親から継承するcustom propertyを用意する（Given）
        let stylesheets = [
            OpenGraphiteCSSStylesheetSource(
                sourceID: "child.css",
                sourceKind: "companion",
                source: ".child { color: var(--tone); }",
                editable: true
            )
        ]
        let element = OpenGraphiteCSSDOMElement(tagName: "span", attributes: ["class": "child"])

        // 検証内容：同じcandidateを継承値あり・なしの最終cascadeで評価する（When）
        let resolved = OpenGraphiteCSSSourceDocument.cascadeTrace(
            for: element,
            stylesheets: stylesheets,
            inheritedValues: ["--tone": "rgb(10, 20, 30)"]
        )
        let unresolved = OpenGraphiteCSSSourceDocument.cascadeTrace(
            for: element,
            stylesheets: stylesheets
        )

        // 期待値：親で解決したcolorはcomplete、真に未解決なcolorだけがnode-level incompleteになる（Then）
        #expect(resolved.resolvedValues["color"] == "rgb(10, 20, 30)")
        #expect(!resolved.incompleteProperties.contains("color"))
        #expect(unresolved.resolvedValues["color"] == nil)
        #expect(unresolved.incompleteProperties.contains("color"))
    }

    /// 論理名（日本語）: 解析済みmulti-stylesheet再利用テスト
    /// 概要: stylesheetを一括解析した内部APIが複数elementでASTを再利用し、従来source APIと完全に同じcascade結果を返すことを確認します。
    @Test("解析済みstylesheetは複数elementでsource APIと同じcascadeを返す")
    func testParsedStylesheetsReuseDocumentsAcrossElements() {
        // コンディション：project tokenとcompanion ruleを別stylesheetに持つ親子elementを用意する（Given）
        let stylesheets = [
            OpenGraphiteCSSStylesheetSource(
                sourceID: "project.css",
                sourceKind: "project",
                source: "html { --tone: rgb(10, 20, 30); }",
                editable: false
            ),
            OpenGraphiteCSSStylesheetSource(
                sourceID: "page.css",
                sourceKind: "companion",
                source: ".child { color: var(--tone); display: flex; }",
                editable: true
            )
        ]
        let root = OpenGraphiteCSSDOMElement(tagName: "html", attributes: [:])
        let child = OpenGraphiteCSSDOMElement(
            tagName: "section",
            attributes: ["class": "child"],
            ancestors: [root]
        )

        // 検証内容：stylesheetを一度だけ一括解析し、親子cascadeをparsed/source両APIで評価する（When）
        let parsedStylesheets = OpenGraphiteCSSSourceDocument.parseStylesheets(stylesheets)
        let parsedRoot = OpenGraphiteCSSSourceDocument.cascadeTrace(
            for: root,
            parsedStylesheets: parsedStylesheets
        )
        let parsedChild = OpenGraphiteCSSSourceDocument.cascadeTrace(
            for: child,
            parsedStylesheets: parsedStylesheets,
            inheritedValues: parsedRoot.resolvedValues
        )
        let sourceRoot = OpenGraphiteCSSSourceDocument.cascadeTrace(
            for: root,
            stylesheets: stylesheets
        )
        let sourceChild = OpenGraphiteCSSSourceDocument.cascadeTrace(
            for: child,
            stylesheets: stylesheets,
            inheritedValues: sourceRoot.resolvedValues
        )

        // 期待値：解析済み文書がsource境界を保持し、親子とも従来APIと完全一致する（Then）
        #expect(parsedStylesheets.map(\.document.source) == stylesheets.map(\.source))
        #expect(parsedRoot == sourceRoot)
        #expect(parsedChild == sourceChild)
        #expect(parsedChild.resolvedValues["color"] == "rgb(10, 20, 30)")
        #expect(parsedChild.winners["color"]?.sourceID == "page.css")
    }

    /// 論理名（日本語）: Var-backed shorthand最終展開テスト
    /// 概要: shorthandをcustom property substitution後にlonghandへ展開し、raw shorthand provenanceを保持します。
    @Test("var-backed shorthandは最終custom property解決後にlonghandへ展開する")
    func testVariableBackedShorthandsExpandAfterFinalResolution() {
        // コンディション：multi-tokenのflex-flow、gap、marginをcustom property経由で指定する（Given）
        let source = """
        .panel {
          --flow: column wrap;
          --space: 8px 12px;
          --edges: 1px 2px 3px 4px;
          display: flex;
          flex-flow: var(--flow);
          gap: var(--space);
          margin: var(--edges);
        }
        .invalid { --flow: column nonsense; display: flex; flex-flow: var(--flow); }
        """
        let document = OpenGraphiteCSSSourceDocument.parse(source)

        // 検証内容：valid/invalid shorthandをfinal cascadeで解決する（When）
        let panel = document.cascadeTrace(
            for: OpenGraphiteCSSDOMElement(tagName: "section", attributes: ["class": "panel"])
        )
        let invalid = document.cascadeTrace(
            for: OpenGraphiteCSSDOMElement(tagName: "section", attributes: ["class": "invalid"])
        )

        // 期待値：component値は置換後tokenから得られ、traceは元shorthandとraw var spellingを指す（Then）
        #expect(panel.resolvedValues["flex-direction"] == "column")
        #expect(panel.resolvedValues["flex-wrap"] == "wrap")
        #expect(panel.resolvedValues["row-gap"] == "8px")
        #expect(panel.resolvedValues["column-gap"] == "12px")
        #expect(panel.resolvedValues["margin-top"] == "1px")
        #expect(panel.resolvedValues["margin-right"] == "2px")
        #expect(panel.resolvedValues["margin-bottom"] == "3px")
        #expect(panel.resolvedValues["margin-left"] == "4px")
        #expect(panel.winners["flex-direction"]?.authoredProperty == "flex-flow")
        #expect(panel.winners["flex-direction"]?.declaration.value == "var(--flow)")
        #expect(panel.winners["column-gap"]?.authoredProperty == "gap")
        #expect(panel.winners["margin-left"]?.authoredProperty == "margin")
        #expect(panel.incompleteProperties.isEmpty)
        #expect(invalid.resolvedValues["flex-direction"] == "row")
        #expect(invalid.resolvedValues["flex-wrap"] == "nowrap")
        #expect(invalid.incompleteProperties.contains("flex-direction"))
        #expect(invalid.incompleteProperties.contains("flex-wrap"))
        #expect(document.source == source)
    }

    /// 論理名（日本語）: Escaped CSS-wide keyword解決テスト
    /// 概要: value位置のCSS identifier escapeをsemantic keywordへ復号し、authored spellingはsource traceへ保持します。
    @Test("escaped CSS-wide keywordはinheritとcustom initial semanticsへ解決する")
    func testEscapedCSSWideKeywordsResolveSemantically() {
        // コンディション：escaped initial custom propertyとescaped inherit displayを親子ruleへ記述する（Given）
        let source = #"""
        .parent { display: flex; --tone: \69nitial; }
        .child { display: \69nherit; color: var(--tone, red); }
        """#
        let document = OpenGraphiteCSSSourceDocument.parse(source)
        let parentElement = OpenGraphiteCSSDOMElement(tagName: "section", attributes: ["class": "parent"])
        let childElement = OpenGraphiteCSSDOMElement(tagName: "span", attributes: ["class": "child"])

        // 検証内容：親computed値を子cascadeへ継承して最終解決する（When）
        let parent = document.cascadeTrace(for: parentElement)
        let child = document.cascadeTrace(for: childElement, inheritedValues: parent.resolvedValues)

        // 期待値：raw escapeを保持しつつdisplayは親flex、guaranteed-invalid custom propertyはfallback redへ解決する（Then）
        #expect(parent.authoredValues["--tone"] == #"\69nitial"#)
        #expect(parent.resolvedValues["--tone"] == nil)
        #expect(child.authoredValues["display"] == #"\69nherit"#)
        #expect(child.resolvedValues["display"] == "flex")
        #expect(child.resolvedValues["color"] == "red")
        #expect(!child.incompleteProperties.contains("display"))
        #expect(!child.incompleteProperties.contains("color"))
        #expect(document.source == source)
    }

    /// 論理名（日本語）: CSS revert継承境界テスト
    /// 概要: origin/layerを断定できない`revert`系でも、継承propertyの親computed値は失いません。
    @Test("revert系は継承propertyの親値を保持し非継承propertyをUA fallbackへ委ねる")
    func testRevertPreservesInheritedComputedValues() {
        // コンディション：継承・非継承propertyのauthor candidateをrevertする子ruleを用意する（Given）
        let source = """
        .child {
          display: grid;
          display: revert;
          visibility: visible;
          visibility: revert;
          overflow-wrap: normal;
          overflow-wrap: revert-layer;
        }
        """
        let element = OpenGraphiteCSSDOMElement(tagName: "span", attributes: ["class": "child"])

        // 検証内容：親computed値を渡してheadless cascadeを解決する（When）
        let trace = OpenGraphiteCSSSourceDocument.parse(source).cascadeTrace(
            for: element,
            inheritedValues: ["visibility": "hidden", "overflow-wrap": "anywhere"]
        )

        // 期待値：displayはUAへ委ね、継承propertyは親値を保持しつつ全revert propertyをincompleteにする（Then）
        #expect(trace.resolvedValues["display"] == nil)
        #expect(trace.resolvedValues["visibility"] == "hidden")
        #expect(trace.resolvedValues["overflow-wrap"] == "anywhere")
        #expect(trace.incompleteProperties.isSuperset(of: ["display", "visibility", "overflow-wrap"]))
        #expect(trace.authoredValues["display"] == "revert")
        #expect(trace.authoredValues["visibility"] == "revert")
        #expect(trace.authoredValues["overflow-wrap"] == "revert-layer")
        #expect(OpenGraphiteCSSSourceDocument.parse(source).source == source)
    }

    /// 論理名（日本語）: 有限keyword CSS値境界テスト
    /// 概要: browserが破棄する有限keyword declarationをwinnerにせず、matching propertyだけを不完全として保持します。
    @Test("invalid finite keyword declarationはwinnerにせずwrite境界を残す")
    func testInvalidFiniteKeywordDeclarationsRemainIncomplete() {
        // コンディション：validな新しいdisplay keywordと、invalid display/flex-flowを別nodeへ記述する（Given）
        let source = """
        .math { display: math; }
        .invalid-display { display: not-a-display; }
        .invalid-flow { display: flex; flex-flow: column nonsense; }
        """
        let document = OpenGraphiteCSSSourceDocument.parse(source)

        // 検証内容：各nodeのsource cascadeを評価する（When）
        let math = document.cascadeTrace(
            for: OpenGraphiteCSSDOMElement(tagName: "math", attributes: ["class": "math"])
        )
        let invalidDisplay = document.cascadeTrace(
            for: OpenGraphiteCSSDOMElement(tagName: "section", attributes: ["class": "invalid-display"])
        )
        let invalidFlow = document.cascadeTrace(
            for: OpenGraphiteCSSDOMElement(tagName: "section", attributes: ["class": "invalid-flow"])
        )

        // 期待値：valid mathは採用し、invalid値はraw sourceを保ったままwinnerを断定しない（Then）
        #expect(math.resolvedValues["display"] == "math")
        #expect(!math.incompleteProperties.contains("display"))
        #expect(invalidDisplay.winners["display"] == nil)
        #expect(invalidDisplay.incompleteProperties.contains("display"))
        #expect(invalidFlow.winners["flex-direction"] == nil)
        #expect(invalidFlow.winners["flex-wrap"] == nil)
        #expect(invalidFlow.incompleteProperties.contains("flex-direction"))
        #expect(invalidFlow.incompleteProperties.contains("flex-wrap"))
        #expect(document.source == source)
    }

    /// 論理名（日本語）: CSS geometry・track grammar境界テスト
    /// 概要: browserが破棄するgeometry、math、grid track値をwinnerにせず、raw sourceとproperty単位の不完全性を保持します。
    @Test("geometryとtrack値は標準grammarだけを解決しinvalid sourceを不完全にする")
    func testGeometryAndTrackValueGrammarPreservesInvalidSourceAsIncomplete() {
        // コンディション：標準unit/functionを使うvalid ruleと、確実にinvalidなgeometry/track ruleを用意する（Given）
        let source = """
        .valid {
          gap: normal 2cqw;
          width: min(100%, 60rem);
          inset: clamp(-2rem, 0px, 3rem) auto;
          grid-template-columns: [start] minmax(0px, 1fr) repeat(2, fit-content(12ch));
          grid-auto-rows: minmax(0, 1fr);
          stroke-width: calc(1 + 1);
          z-index: calc(1 + 1);
          scale: calc(100% - 10%) calc(1 + .2);
          line-height: calc(1 + .2);
        }
        .invalid {
          gap: nonsense;
          width: min();
          inset: 0 0 0 0 0;
          grid-template-columns: repeat(nonsense);
          grid-auto-rows: minmax(nonsense, 1fr);
          stroke-width: calc(nonsense);
          z-index: 1.5;
          scale: calc(1px);
          scale: calc(100% - 1px);
          scale: calc(100% - .2);
          line-height: calc(1 + 1px);
        }
        .environment {
          width: env(safe-area-inset-left);
          left: anchor(--card right);
          height: anchor-size(--card width);
        }
        """
        let document = OpenGraphiteCSSSourceDocument.parse(source)

        // 検証内容：valid/invalid nodeの最終cascade traceを生成する（When）
        let valid = document.cascadeTrace(
            for: OpenGraphiteCSSDOMElement(tagName: "section", attributes: ["class": "valid"])
        )
        let invalid = document.cascadeTrace(
            for: OpenGraphiteCSSDOMElement(tagName: "section", attributes: ["class": "invalid"])
        )
        let environment = document.cascadeTrace(
            for: OpenGraphiteCSSDOMElement(tagName: "section", attributes: ["class": "environment"])
        )

        // 期待値：valid値は解決され、invalid値だけがraw bytesを変えず該当propertyへwrite blockを残す（Then）
        #expect(valid.resolvedValues["gap"] == "normal 2cqw")
        #expect(valid.resolvedValues["width"] == "min(100%, 60rem)")
        #expect(valid.resolvedValues["top"] == "clamp(-2rem, 0px, 3rem)")
        #expect(valid.resolvedValues["grid-auto-rows"] == "minmax(0, 1fr)")
        #expect(valid.resolvedValues["stroke-width"] == "calc(1 + 1)")
        #expect(valid.resolvedValues["z-index"] == "calc(1 + 1)")
        #expect(valid.resolvedValues["scale"] == "calc(100% - 10%) calc(1 + .2)")
        #expect(valid.resolvedValues["line-height"] == "calc(1 + .2)")
        #expect(valid.incompleteProperties.isEmpty)
        #expect(invalid.winners["gap"] == nil)
        #expect(invalid.winners["width"] == nil)
        #expect(invalid.winners["grid-template-columns"] == nil)
        #expect(invalid.winners["stroke-width"] == nil)
        #expect(invalid.incompleteProperties.isSuperset(of: [
            "gap", "row-gap", "column-gap", "width", "top", "right", "bottom", "left",
            "grid-template-columns", "grid-auto-rows", "stroke-width", "z-index", "scale",
            "line-height"
        ]))
        #expect(environment.authoredValues["width"] == "env(safe-area-inset-left)")
        #expect(environment.resolvedValues["width"] == nil)
        #expect(environment.authoredValues["left"] == "anchor(--card right)")
        #expect(environment.authoredValues["height"] == "anchor-size(--card width)")
        #expect(environment.resolvedValues["left"] == nil)
        #expect(environment.resolvedValues["height"] == nil)
        #expect(environment.incompleteProperties.isSuperset(of: ["width", "left", "height"]))
        #expect(document.source == source)
    }

    /// 論理名（日本語）: CSS setter value境界tokenテスト
    /// 概要: declaration境界へ到達するsemicolon/priorityを拒否し、comment/string/function内tokenは誤って境界扱いしません。
    @Test("property valueのtop-level injection tokenだけを拒否する")
    func testPropertyValueBoundaryRejectsTopLevelInjectionTokens() {
        // コンディション：top-level injectionと、同じ記号をcomment/function内に持つ値を用意する（Given）
        let injected = ["8px; color: red", "8px !important"]
        let preserved = ["8px /* ; !important */", "calc(4px + 4px)"]

        // 検証内容：Shared setterと同じproperty value validatorへ渡す（When）
        let injectedResults = injected.map {
            OpenGraphiteCSSSourceDocument.isValidCSSPropertyValue($0, for: "gap")
        }
        let preservedResults = preserved.map {
            OpenGraphiteCSSSourceDocument.isValidCSSPropertyValue($0, for: "gap")
        }
        let functionSemicolon = OpenGraphiteCSSSourceDocument.isValidCSSPropertyValue(
            #"url("data:image/svg+xml;a;b")"#,
            for: "background-image"
        )

        // 期待値：outer declarationを逸脱する値だけをatomic rejectし、opaque raw valueは保持可能とする（Then）
        #expect(injectedResults == [false, false])
        #expect(preservedResults == [true, true])
        #expect(functionSemicolon == true)
    }

    /// 論理名（日本語）: CSS shorthand traceテスト
    /// 概要: paddingとgap shorthandをlonghandへ展開しつつauthored provenanceを保持することを確認します。
    @Test("shorthandをlonghandへ展開してauthored provenanceを保持する")
    func testShorthandExpansionKeepsAuthoredProvenance() {
        // コンディション：2値paddingと単一gapを持つruleがある（Given）
        let source = ".panel { padding: 12px 20px; gap: var(--space, 8px); }"
        let element = OpenGraphiteCSSDOMElement(tagName: "section", attributes: ["class": "panel"])

        // 検証内容：cascade traceを生成する（When）
        let trace = OpenGraphiteCSSSourceDocument.parse(source).cascadeTrace(for: element)

        // 期待値：4辺とrow/column gapが解決され、書き戻し元はshorthandのままになる（Then）
        #expect(trace.authoredValues["padding-top"] == "12px")
        #expect(trace.authoredValues["padding-right"] == "20px")
        #expect(trace.authoredValues["padding-bottom"] == "12px")
        #expect(trace.authoredValues["padding-left"] == "20px")
        #expect(trace.winners["padding-left"]?.authoredProperty == "padding")
        #expect(trace.authoredValues["row-gap"] == "var(--space, 8px)")
    }

    /// 論理名（日本語）: CSS media scopeテスト
    /// 概要: baseとactive media ruleを区別し、at-rule provenanceを保持することを確認します。
    @Test("media ruleはactive条件だけをcascadeへ適用する")
    func testMediaRuleActivationAndProvenance() {
        // コンディション：baseとmobile media scopeに同じselectorがある（Given）
        let source = """
        .card { display: grid; gap: 24px; }
        @media (max-width: 720px) {
          /* keep-media */
          .card { display: block; gap: 12px !important; }
        }
        """
        let element = OpenGraphiteCSSDOMElement(tagName: "article", attributes: ["class": "card"])

        // 検証内容：base環境とmobile環境でcascadeを評価する（When）
        let document = OpenGraphiteCSSSourceDocument.parse(source)
        let base = document.cascadeTrace(for: element)
        let mobile = document.cascadeTrace(
            for: element,
            environment: OpenGraphiteCSSCascadeEnvironment(
                activeMediaQueries: ["(max-width: 720px)"],
                includeUnknownConditionalRules: false
            )
        )

        // 期待値：baseはgrid、mobileはblockとなり、winnerにmedia条件が残る（Then）
        #expect(base.authoredValues["display"] == "grid")
        #expect(mobile.authoredValues["display"] == "block")
        #expect(mobile.authoredValues["gap"] == "12px")
        #expect(mobile.winners["display"]?.atRules.first?.name == "media")
    }

    /// 論理名（日本語）: Responsive標準layout最小差分テスト
    /// 概要: active media条件をCSSOM互換のtoken表現へ正規化し、標準layout winnerのvalue rangeだけを更新します。
    @Test("active media標準layout winnerだけを最小差分更新する")
    func testActiveMediaStandardLayoutWinnerUsesMinimalDiff() {
        // コンディション：base grid、responsive flex、unknown conditional ruleとcommentを持つsourceを用意する（Given）
        let source = """
        .panel { display: grid; grid-template-columns: 1fr 2fr; }
        @media   (MAX-WIDTH:720px) {
          /* keep-media */
          .panel { display: flex; flex-direction : column; }
        }
        @supports (display: subgrid) { .panel { display: subgrid; } }
        """
        let element = OpenGraphiteCSSDOMElement(tagName: "section", attributes: ["class": "panel"])
        var companion = OpenGraphiteCompanionCSSDocument(css: source)

        // 検証内容：重複・余分な空白を含むactive条件でtraceを解決し、flex-directionだけを更新する（When）
        let environment = OpenGraphiteCSSCascadeEnvironment.inspection(
            activeMediaQueries: ["  (max-width:   720px) ", "(MAX-WIDTH:720px)"]
        )
        let trace = OpenGraphiteCSSSourceDocument.parse(source).cascadeTrace(
            for: element,
            environment: environment
        )
        companion.setCSSProperty(
            "flex-direction",
            value: "row",
            for: element,
            fallbackSelector: ".panel",
            activeMediaQueries: ["  (max-width:   720px) "]
        )

        // 期待値：mediaだけがactiveで、authored at-rule/trivia/unknown ruleを保ったままvalueだけが変わる（Then）
        #expect(environment.activeMediaQueries == ["(max-width: 720px)"])
        #expect(trace.resolvedValues["display"] == "flex")
        #expect(trace.resolvedValues["flex-direction"] == "column")
        #expect(trace.winners["display"]?.atRules == [
            OpenGraphiteCSSAtRuleContext(name: "media", prelude: "(MAX-WIDTH:720px)")
        ])
        #expect(companion.css == source.replacingOccurrences(
            of: "flex-direction : column",
            with: "flex-direction : row"
        ))
        #expect(companion.css.contains("@supports (display: subgrid)"))
        #expect(companion.css.contains("/* keep-media */"))
    }

    /// 論理名（日本語）: Media条件CSSOM canonicalizationテスト
    /// 概要: colon、range operator、comma、case、commentの表記差をactive照合用semantic keyだけで正規化します。
    @Test("media条件はCSSOM相当のsemantic keyへcanonicalizeする")
    func testMediaConditionCanonicalizationMatchesCSSOMSpelling() {
        // コンディション：authoredとCSSOMで空白・caseが異なcolon/range条件を用意する（Given）
        let authored = "(MIN-WIDTH:500px)/**/and(400px<WIDTH<=1000px),PRINT"
        let cssom = "(min-width: 500px) and (400px < width <= 1000px), print"

        // 検証内容：graph/CLI/MCPとsource cascadeが共有するactive media keyへ正規化する（When）
        let normalized = OpenGraphiteCSSCascadeEnvironment.normalizedActiveMediaQueries([
            authored,
            cssom,
            "  \(cssom)  "
        ])

        // 期待値：CSSOM spellingで決定的にechoし、semantic duplicateは1件になる（Then）
        #expect(normalized == [cssom])
    }

    /// 論理名（日本語）: CSS declaration最小差分テスト
    /// 概要: 既存declarationのvalueだけを変更し、周辺comment、未知rule、importantを保持することを確認します。
    @Test("部分編集は対象valueだけを変更して周辺sourceを保持する")
    func testMinimalDeclarationPatchPreservesTrivia() {
        // コンディション：commentと未知ruleに囲まれたimportant declarationがある（Given）
        let source = """
        /* before */
        .card {
          color : rgb(1, 2, 3) !important; /* keep */
          future-value: fn(a; b);
        }
        @unknown token { raw { thing: value; } }
        """
        let element = OpenGraphiteCSSDOMElement(tagName: "div", attributes: ["class": "card"])
        let document = OpenGraphiteCSSSourceDocument.parse(source)
        let provenance = document.cascadeTrace(for: element).winners["color"]

        // 検証内容：colorだけを新しい値へ更新する（When）
        let updated = document.setting(
            property: "color",
            value: "rgb(9, 8, 7)",
            provenance: provenance,
            fallbackSelector: ".card"
        )

        // 期待値：value以外の空白、important、comment、未知ruleがbyte相当で保持される（Then）
        #expect(updated == source.replacingOccurrences(of: "rgb(1, 2, 3)", with: "rgb(9, 8, 7)"))
    }

    /// 論理名（日本語）: CSS declaration lexer境界テスト
    /// 概要: simple block、quote、comment、escape内のsemicolonを保持し、trivia付きproperty名とpriorityを意味解析します。
    @Test("declaration lexerはblockとescapeを保持してtrivia付きpriorityを評価する")
    func testDeclarationLexerPreservesBlocksEscapesAndImportantTrivia() throws {
        // コンディション：property名comment、2種類のimportant、block内semicolon、escaped delimiterを含むCSSがある（Given）
        let source = #"""
        .card {
          color/**/: rgb(1, 2, 3) /**/ ! /**/ important; /* keep */
          outline-color: navy ! important;
          --payload: { alpha: one; priority: ! important; beta: [x; y]; };
          --escaped: left\}middle\;tail;
          future-property: fn([a; b], { c: d; e: f; });
          background-image: url("data:image/svg+xml;a;b");
        }
        #card { color: green; outline-color: teal; }
        """#
        let element = OpenGraphiteCSSDOMElement(
            tagName: "article",
            attributes: ["id": "card", "class": "card"]
        )

        // 検証内容：lossless parserでdeclarationを索引化し、標準cascadeを評価する（When）
        let document = OpenGraphiteCSSSourceDocument.parse(source)
        let firstRule = try #require(document.rules.first)
        let trace = document.cascadeTrace(for: element)

        // 期待値：内側delimiterは値に残り、両importantが高specificityの通常宣言より勝ち、sourceは無変更となる（Then）
        #expect(document.rules.count == 2)
        #expect(firstRule.declarations.map(\.name) == [
            "color", "outline-color", "--payload", "--escaped", "future-property", "background-image"
        ])
        #expect(firstRule.declarations[0].value == "rgb(1, 2, 3)")
        #expect(firstRule.declarations[0].important)
        #expect(firstRule.declarations[1].important)
        #expect(firstRule.declarations[2].value == "{ alpha: one; priority: ! important; beta: [x; y]; }")
        #expect(!firstRule.declarations[2].important)
        #expect(firstRule.declarations[3].value == #"left\}middle\;tail"#)
        #expect(firstRule.declarations[4].value == "fn([a; b], { c: d; e: f; })")
        #expect(firstRule.declarations[5].value == "url(\"data:image/svg+xml;a;b\")")
        #expect(trace.authoredValues["color"] == "rgb(1, 2, 3)")
        #expect(trace.winners["color"]?.selector == ".card")
        #expect(trace.authoredValues["outline-color"] == "navy")
        #expect(trace.winners["outline-color"]?.selector == ".card")
        #expect(document.source == source)
    }

    /// 論理名（日本語）: Trivia付きCSS declaration最小差分テスト
    /// 概要: priorityのraw triviaを保持したvalue更新と、block値を持つcustom propertyだけの削除を確認します。
    @Test("trivia付きdeclarationの更新とblock値の削除は対象rangeだけを変更する")
    func testDeclarationMutationPreservesRawPriorityAndNeighborValues() throws {
        // コンディション：comment分離property、raw priority、block値、未知propertyが同じruleにある（Given）
        let source = #"""
        .card {
          color/**/: red /**/ ! /**/ important; /* keep-priority */
          --payload: { alpha: one; beta: [x; y]; escaped: left\;right; };
          future-property: fn([a; b], { c: d; e: f; }); /* keep-unknown */
        }
        """#
        let element = OpenGraphiteCSSDOMElement(tagName: "div", attributes: ["class": "card"])
        let document = OpenGraphiteCSSSourceDocument.parse(source)
        let trace = document.cascadeTrace(for: element)
        let color = try #require(trace.winners["color"])
        let payload = try #require(trace.winners["--payload"])

        // 検証内容：同じsourceからcolor value更新とcustom property削除をそれぞれ行う（When）
        let updated = document.setting(
            property: "color",
            value: "blue",
            provenance: color,
            fallbackSelector: ".card"
        )
        let removed = document.setting(
            property: "--payload",
            value: "",
            provenance: payload,
            fallbackSelector: ".card"
        )
        let removedTrace = OpenGraphiteCSSSourceDocument.parse(removed).cascadeTrace(for: element)

        // 期待値：更新・削除対象以外のtrivia、block値、未知propertyはbyte相当で保持される（Then）
        #expect(updated == source.replacingOccurrences(of: "red", with: "blue"))
        #expect(removed == source.replacingOccurrences(
            of: #"--payload: { alpha: one; beta: [x; y]; escaped: left\;right; };"#,
            with: ""
        ))
        #expect(removedTrace.winners["--payload"] == nil)
        #expect(removedTrace.authoredValues["color"] == "red")
        #expect(removedTrace.authoredValues["future-property"] == "fn([a; b], { c: d; e: f; })")
    }

    /// 論理名（日本語）: Escaped CSS property・priority意味解析テスト
    /// 概要: identifier escapeをsemantic property名とimportantへ復号しつつ、authored spellingの最小差分を保持します。
    @Test("escaped propertyとimportantをsemantic照合してraw rangeだけを編集する")
    func testEscapedPropertyAndImportantSupportCascadeSetAndRemove() throws {
        // コンディション：simple escapeとhex escapeのcolor、escaped important、literal escaped bangを含むCSSがある（Given）
        let source = #"""
        .literal {
          co\lor: red !\69mportant;
          future-property: token \!important;
        }
        .hex { co\6c or: blue; }
        #target { color: green; }
        """#
        let element = OpenGraphiteCSSDOMElement(
            tagName: "article",
            attributes: ["id": "target", "class": "literal hex"]
        )

        // 検証内容：全ruleを索引化してcascadeを評価し、escaped declarationを更新・削除する（When）
        let document = OpenGraphiteCSSSourceDocument.parse(source)
        let literalRule = try #require(document.rules.first)
        let hexRule = try #require(document.rules.dropFirst().first)
        let trace = document.cascadeTrace(for: element)
        let color = try #require(trace.winners["color"])
        let updated = document.setting(
            property: "color",
            value: "purple",
            provenance: color,
            fallbackSelector: ".literal"
        )
        let removed = document.setting(
            property: "color",
            value: "",
            provenance: color,
            fallbackSelector: ".literal"
        )

        // 期待値：両property spellingはcolorとなり、escaped importantだけがpriorityで、mutationはvalue/declaration範囲に限定される（Then）
        #expect(literalRule.declarations.map(\.name) == ["color", "future-property"])
        #expect(literalRule.declarations[0].important)
        #expect(!literalRule.declarations[1].important)
        #expect(literalRule.declarations[1].value == #"token \!important"#)
        #expect(hexRule.declarations.first?.name == "color")
        #expect(trace.authoredValues["color"] == "red")
        #expect(trace.winners["color"]?.selector == ".literal")
        #expect(updated == source.replacingOccurrences(of: "red", with: "purple"))
        #expect(removed == source.replacingOccurrences(of: #"co\lor: red !\69mportant;"#, with: ""))
        #expect(document.source == source)
    }

    /// 論理名（日本語）: Escaped selector・custom property解決テスト
    /// 概要: class/ID/typeとcustom propertyのidentifier escapeを復号し、balanced fallbackとcycleを安全に解決します。
    @Test("escaped selectorとcustom propertyはbalanced var fallbackで標準cascadeを共有する")
    func testEscapedSelectorsAndCustomPropertiesUseSemanticIdentifiers() throws {
        // コンディション：escaped class/ID/type、escaped custom property、nested fallback、循環参照を含むCSSがある（Given）
        let source = #"""
        :root {
          --color: rgb(11, 22, 33);
          --t\6f ne: rgb(44, 55, 66);
          --a: var(--b);
          --b: var(--a);
        }
        .c\61 rd.foo\+bar#hero\+id {
          color: var(--c\6f lor, color-mix(in srgb, black 50%, white));
          background-color: var(--missing, var(--c\6f lor));
          border-color: var(--a, red);
          --nested: var(--missing, color-mix(in srgb, var(--c\6f lor) 50%, blue));
          --quoted: var(--missing, "comma, close)");
          --commented: var(--missing, blue /* comma, close) */);
          --escaped-fallback: var(--missing, token\,right\));
        }
        custom\2d element { outline-color: var(--tone); }
        """#
        let root = OpenGraphiteCSSDOMElement(tagName: "html", isRoot: true)
        let element = OpenGraphiteCSSDOMElement(
            tagName: "custom-element",
            attributes: ["id": "hero+id", "class": "card foo+bar"],
            ancestors: [OpenGraphiteCSSDOMElement(tagName: "body"), root]
        )

        // 検証内容：root custom propertiesを継承し、escaped selectorのelementへsource cascadeを適用する（When）
        let document = OpenGraphiteCSSSourceDocument.parse(source)
        let rootTrace = document.cascadeTrace(for: root)
        let trace = document.cascadeTrace(for: element, inheritedValues: rootTrace.resolvedValues)

        // 期待値：identifierはsemantic値で一致し、defined/missing/cyclic varはbalancedに解決され、raw sourceは保持される（Then）
        #expect(rootTrace.authoredValues["--color"] == "rgb(11, 22, 33)")
        #expect(rootTrace.authoredValues["--tone"] == "rgb(44, 55, 66)")
        #expect(OpenGraphiteCSSSelector.matches(#".c\61 rd.foo\+bar#hero\+id"#, element: element))
        #expect(OpenGraphiteCSSSelector.matches(#"custom\2d element"#, element: element))
        #expect(OpenGraphiteCSSSelector.specificity(of: #".c\61 rd.foo\+bar#hero\+id"#) ==
            OpenGraphiteCSSSpecificity(ids: 1, classes: 2, types: 0))
        #expect(trace.authoredValues["color"] == "var(--c\\6f lor, color-mix(in srgb, black 50%, white))")
        #expect(trace.resolvedValues["color"] == "rgb(11, 22, 33)")
        #expect(trace.resolvedValues["background-color"] == "rgb(11, 22, 33)")
        #expect(trace.resolvedValues["border-color"] == "red")
        #expect(trace.resolvedValues["--nested"] ==
            "color-mix(in srgb, rgb(11, 22, 33) 50%, blue)")
        #expect(trace.resolvedValues["--quoted"] == "\"comma, close)\"")
        #expect(trace.resolvedValues["--commented"] == "blue /* comma, close) */")
        #expect(trace.resolvedValues["--escaped-fallback"] == #"token\,right\)"#)
        #expect(trace.resolvedValues["outline-color"] == "rgb(44, 55, 66)")
        #expect(trace.winners["color"]?.selector == #".c\61 rd.foo\+bar#hero\+id"#)
        #expect(trace.winners["outline-color"]?.selector == #"custom\2d element"#)
        #expect(document.source == source)
    }

    /// 論理名（日本語）: CSS safe rule追加テスト
    /// 概要: matching declarationがない場合に既存selector bodyへ新規declarationだけを追記することを確認します。
    @Test("provenanceがない編集は安全な既存selectorへ追記する")
    func testSafeRuleInsertionUsesExistingSelector() {
        // コンディション：編集対象propertyを持たない既存selector ruleがある（Given）
        let source = ".card {\n  color: black;\n}\n"
        let document = OpenGraphiteCSSSourceDocument.parse(source)

        // 検証内容：fallback selectorへpaddingを追加する（When）
        let updated = document.setting(
            property: "padding",
            value: "16px",
            provenance: nil,
            fallbackSelector: ".card"
        )

        // 期待値：既存colorを変更せず同じruleへpaddingだけが追加される（Then）
        #expect(updated == ".card {\n  color: black;\n  padding: 16px;\n}\n")
    }

    /// 論理名（日本語）: Companion CSS汎用selectorテスト
    /// 概要: data-og selectorのないtag/class selectorからnode design valueを抽出できることを確認します。
    @Test("Companion CSSは標準tagとclass selectorから宣言を取得する")
    func testCompanionCSSUsesStandardSelectors() {
        // コンディション：標準tag/class selectorだけを持つcompanion CSSと注釈済みHTMLがある（Given）
        let html = "<article data-og-id=\"card\" class=\"featured\" data-og-internal-id=\"card-node\">Hello</article>"
        let css = OpenGraphiteCompanionCSSDocument(css: "article { padding: 8px; } article.featured { padding: 20px; color: navy; }")

        // 検証内容：HTML graphをcompanion CSS付きで抽出する（When）
        let nodes = OpenGraphiteHTMLDocument(html: html).nodes(companionCSS: css)

        // 期待値：specificityの高い標準selectorの値がagent nodeへ反映される（Then）
        #expect(nodes.count == 1)
        #expect(nodes[0].cssVariables["padding"] == "20px")
        #expect(nodes[0].cssVariables["color"] == "navy")
    }

    /// 論理名（日本語）: Locale typography source一覧テスト
    /// 概要: defaultと任意localeの標準font-familyだけをroot selector scopeから抽出します。
    @Test("locale typographyはdefaultと任意BCP47 ruleをsource provenance付きで列挙する")
    func testLocaleTypographyListsDefaultAndArbitraryLocaleRules() {
        // コンディション：default、ja、underscore表記のfr-CA、element override、未知ruleを含むCSSがある（Given）
        let css = """
        /* keep */
        #app { font-family: Inter, sans-serif; }
        #app:lang(ja) { font-family: "Noto Sans JP", sans-serif; }
        @media (min-width: 40rem) {
          #app:lang('fr_CA') { font-family: Marianne, sans-serif !important; }
        }
        #app .brand { font-family: Display, serif; }
        @future typography { raw { untouched: yes; } }
        """
        let document = OpenGraphiteCompanionCSSDocument(css: css)

        // 検証内容：#app scopeのlocale typographyを列挙する（When）
        let declarations = document.localeTypography(rootSelector: "#app")

        // 期待値：element overrideを混ぜず、locale正規化とsource provenanceを保持する（Then）
        #expect(declarations.map(\.locale) == ["default", "ja", "fr-CA"])
        #expect(declarations.map(\.value) == [
            "Inter, sans-serif",
            "\"Noto Sans JP\", sans-serif",
            "Marianne, sans-serif"
        ])
        #expect(declarations[2].important)
        #expect(declarations[2].atRules == [
            OpenGraphiteCSSAtRuleContext(name: "media", prelude: "(min-width: 40rem)")
        ])
        #expect(!declarations.contains { $0.selector.contains(".brand") })
    }

    /// 論理名（日本語）: Locale typography最小差分更新テスト
    /// 概要: BCP47をcase-insensitiveに照合し、既存selector・at-rule・important・commentを保持します。
    @Test("locale typography更新は既存selector scopeのvalueだけを変更する")
    func testLocaleTypographyUpdatePreservesSelectorScopeAndTrivia() throws {
        // コンディション：authored casing、underscore、media scope、important、commentを持つlocale ruleがある（Given）
        let source = """
        /* before */
        @media (min-width: 40rem) {
          #app:lang('fr_CA') {
            font-family : Old, sans-serif !important; /* keep-inline */
            future-property: fn(a; b);
          }
        }
        /* after */
        """
        var document = OpenGraphiteCompanionCSSDocument(css: source)

        // 検証内容：caseとseparatorが異なる同一BCP47 localeを更新する（When）
        let result = document.setLocaleTypography(
            locale: "FR-ca",
            fontFamily: "Marianne, sans-serif",
            rootSelector: "#app"
        )
        let mutation = try #require(result)

        // 期待値：authored selector/scope/triviaはbyte保持され、valueだけが置換される（Then）
        #expect(mutation.locale == "fr-CA")
        #expect(mutation.selector == "#app:lang('fr_CA')")
        #expect(document.css == source.replacingOccurrences(of: "Old, sans-serif", with: "Marianne, sans-serif"))
    }

    /// 論理名（日本語）: Locale typography at-rule追加テスト
    /// 概要: 新しいlocale ruleをdefault宣言と同じauthored at-rule scopeへ追加します。
    @Test("新しいlocale typographyはdefaultと同じat-rule scopeへ追加する")
    func testLocaleTypographyInsertionPreservesDefaultAtRuleScope() throws {
        // コンディション：media scope内だけにdefault root font-familyがある（Given）
        var document = OpenGraphiteCompanionCSSDocument(
            css: """
            /* keep */
            @media print {
              #app {
                font-family: Charter, serif;
              }
            }
            @future typography { raw { untouched: yes; } }
            """
        )

        // 検証内容：新しいfr-CA localeを設定する（When）
        let result = document.setLocaleTypography(
            locale: "fr_CA",
            fontFamily: "Marianne, sans-serif",
            rootSelector: "#app"
        )
        let mutation = try #require(result)
        let declarations = document.localeTypography(rootSelector: "#app")
        let locale = try #require(declarations.first { $0.locale == "fr-CA" })

        // 期待値：新ruleはmedia block内で同じindentationを使い、未知rule/commentを保持する（Then）
        #expect(mutation.selector == "#app:lang(\"fr-CA\")")
        #expect(locale.atRules == [OpenGraphiteCSSAtRuleContext(name: "media", prelude: "print")])
        #expect(document.css.contains("  #app:lang(\"fr-CA\") {"))
        #expect(document.css.contains("/* keep */"))
        #expect(document.css.contains("@future typography { raw { untouched: yes; } }"))
    }

    /// 論理名（日本語）: Locale typography安全追加テスト
    /// 概要: 任意の妥当なBCP47 tagをcanonical selectorへ追加し、不正selector入力を拒否します。
    @Test("locale typographyは任意BCP47を安全に追加して冪等更新する")
    func testLocaleTypographyAddsArbitraryLocaleSafelyAndIdempotently() throws {
        // コンディション：font宣言のないroot ruleがある（Given）
        var document = OpenGraphiteCompanionCSSDocument(css: "#app {\n  color: black;\n}\n")

        // 検証内容：script/region付きlocaleを追加し、同値を再設定して、不正localeも試す（When）
        let firstResult = document.setLocaleTypography(
            locale: "ZH_hant_tw",
            fontFamily: "\"Noto Sans TC\", sans-serif",
            rootSelector: "#app"
        )
        let first = try #require(firstResult)
        let once = document.css
        let secondResult = document.setLocaleTypography(
            locale: "zh-Hant-TW",
            fontFamily: "\"Noto Sans TC\", sans-serif",
            rootSelector: "#app"
        )
        let second = try #require(secondResult)
        let rejected = document.setLocaleTypography(
            locale: "ja) { color: red; }",
            fontFamily: "Unsafe",
            rootSelector: "#app"
        )

        // 期待値：canonical :lang selectorが生成され、再設定と不正入力はsourceを変更しない（Then）
        #expect(first.locale == "zh-Hant-TW")
        #expect(first.selector == "#app:lang(\"zh-Hant-TW\")")
        #expect(second.locale == "zh-Hant-TW")
        #expect(document.css == once)
        #expect(rejected == nil)
    }

    /// 論理名（日本語）: Locale typography標準cascadeテスト
    /// 概要: default、locale override、element overrideが標準`:lang()`とinheritanceだけで解決されます。
    @Test("defaultとlocaleとelement font overrideを標準cascadeで解決する")
    func testLocaleTypographyCascadeUsesStandardLangAndInheritance() {
        // コンディション：root default、fr-CA override、child固有overrideを持つCSSがある（Given）
        let source = """
        #app { font-family: Inter, sans-serif; }
        #app:lang(fr-CA) { font-family: Marianne, sans-serif; }
        #app .brand { font-family: Display, serif; }
        """
        let css = OpenGraphiteCSSSourceDocument.parse(source)
        let root = OpenGraphiteCSSDOMElement(
            tagName: "main",
            attributes: ["id": "app", "lang": "fr_CA"]
        )
        let regularChild = OpenGraphiteCSSDOMElement(tagName: "p", ancestors: [root])
        let brandedChild = OpenGraphiteCSSDOMElement(
            tagName: "p",
            attributes: ["class": "brand"],
            ancestors: [root]
        )

        // 検証内容：rootと2種類のchildを標準cascadeで評価する（When）
        let rootTrace = css.cascadeTrace(for: root)
        let regularTrace = css.cascadeTrace(for: regularChild, inheritedValues: rootTrace.resolvedValues)
        let brandedTrace = css.cascadeTrace(for: brandedChild, inheritedValues: rootTrace.resolvedValues)

        // 期待値：locale fontが継承され、element固有fontだけがそれを上書きする（Then）
        #expect(rootTrace.resolvedValues["font-family"] == "Marianne, sans-serif")
        #expect(regularTrace.resolvedValues["font-family"] == "Marianne, sans-serif")
        #expect(brandedTrace.resolvedValues["font-family"] == "Display, serif")
    }

    /// 論理名（日本語）: Omitted document section CSS DOM投影テスト
    /// 概要: sourceにないhtml/head/bodyをAgent graphへ追加せず、標準root/descendant selectorとcustom property継承だけをbrowser同様に評価します。
    @Test("omitted html head bodyはauthored graphを保ったままbrowser CSS treeで評価する")
    func testOmittedDocumentSectionsUseBrowserCSSProjectionWithoutSyntheticGraphNodes() throws {
        // コンディション：document section tagを省略した標準HTMLとroot/body selectorを持つcompanion CSSがある（Given）
        let html = """
        <!doctype html>
        <title id="page-title">Parity</title>
        <main id="app"><article id="card">Card</article></main>
        """
        let css = OpenGraphiteCompanionCSSDocument(css: """
        :root { --tone: rgb(11, 22, 33); }
        body main { color: var(--tone); }
        html > body > main { background: rgb(44, 55, 66); }
        """)
        let document = OpenGraphiteHTMLDocument(html: html)
        let beforeHash = OpenGraphiteHTMLDocument.contentHash(html)

        // 検証内容：authored node graphとcompanion CSS cascadeを同時に抽出する（When）
        let nodes = document.nodes(companionCSS: css, documentURL: "file:///omitted.html")
        let main = try #require(nodes.first { $0.attributes["id"] == "app" })
        let title = try #require(nodes.first { $0.attributes["id"] == "page-title" })

        // 期待値：synthetic sectionはgraphへ出ず、root tokenと両descendant selectorだけがmainへ適用されsource bytesも不変となる（Then）
        #expect(nodes.map(\.tagName) == ["title", "main", "article"])
        #expect(title.parentReference == nil)
        #expect(main.parentReference == nil)
        #expect(main.cssResolvedValues["--tone"] == "rgb(11, 22, 33)")
        #expect(main.cssResolvedValues["color"] == "rgb(11, 22, 33)")
        #expect(main.cssResolvedValues["background"] == "rgb(44, 55, 66)")
        #expect(main.cssSourceTrace["color"]?.map(\.selector) == ["body main"])
        #expect(main.cssSourceTrace["background"]?.map(\.selector) == ["html > body > main"])
        #expect(document.html == html)
        #expect(OpenGraphiteHTMLDocument.contentHash(document.html) == beforeHash)
        let mainRange = main.locator.sourceRange
        let mainStart = html.index(html.startIndex, offsetBy: mainRange.start)
        let mainEnd = html.index(html.startIndex, offsetBy: mainRange.end)
        #expect(String(html[mainStart..<mainEnd]) == "<main id=\"app\"><article id=\"card\">Card</article></main>")
    }

    /// 論理名（日本語）: Implicit table container CSS DOM投影テスト
    /// 概要: source直下のcol/trをauthored parentのままinspectionし、CSS評価時だけcolgroup/tbody配下へ投影します。
    @Test("implicit tbody colgroupはbrowser child selectorだけに反映してauthored parentを保持する")
    func testImplicitTableContainersAffectOnlyBrowserCSSProjection() throws {
        // コンディション：colgroup/tbody開始tagを省略したtableと、browser treeを区別するchild selectorがある（Given）
        let html = """
        <table id="metrics">
          <col id="metric-column">
          <tr id="metric-row"><td id="metric-cell">42</td></tr>
        </table>
        """
        let css = OpenGraphiteCompanionCSSDocument(css: """
        table > col { width: 1px; }
        table > colgroup > col { width: 42px; }
        table > tr { color: rgb(1, 1, 1); }
        table > tbody > tr { color: rgb(2, 3, 4); }
        """)
        let document = OpenGraphiteHTMLDocument(html: html)
        let beforeHash = OpenGraphiteHTMLDocument.contentHash(html)

        // 検証内容：table fixtureをannotationなしでinspectionし、source selector traceを評価する（When）
        let nodes = document.nodes(companionCSS: css, documentURL: "file:///table.html")
        let table = try #require(nodes.first { $0.attributes["id"] == "metrics" })
        let column = try #require(nodes.first { $0.attributes["id"] == "metric-column" })
        let row = try #require(nodes.first { $0.attributes["id"] == "metric-row" })
        let cell = try #require(nodes.first { $0.attributes["id"] == "metric-cell" })

        // 期待値：browserが補うcontainer selectorだけが一致し、graphの親・node数・range・source hashはauthored HTMLのままとなる（Then）
        #expect(nodes.map(\.tagName) == ["table", "col", "tr", "td"])
        #expect(column.parentReference == table.reference)
        #expect(row.parentReference == table.reference)
        #expect(cell.parentReference == row.reference)
        #expect(column.cssResolvedValues["width"] == "42px")
        #expect(column.cssSourceTrace["width"]?.map(\.selector) == ["table > colgroup > col"])
        #expect(row.cssResolvedValues["color"] == "rgb(2, 3, 4)")
        #expect(row.cssSourceTrace["color"]?.map(\.selector) == ["table > tbody > tr"])
        #expect(document.html == html)
        #expect(OpenGraphiteHTMLDocument.contentHash(document.html) == beforeHash)
        for node in nodes {
            let start = html.index(html.startIndex, offsetBy: node.locator.sourceRange.start)
            let end = html.index(html.startIndex, offsetBy: node.locator.sourceRange.end)
            #expect(String(html[start..<end]).hasPrefix("<\(node.tagName)"))
        }
    }

    /// 論理名（日本語）: Explicit document/table structure CSS回帰テスト
    /// 概要: authored html/body/colgroup/tbodyを重複投影せず、既存の標準selectorとsource parentを維持します。
    @Test("explicit document sectionとtable sectionは重複せず従来どおり評価する")
    func testExplicitDocumentAndTableSectionsRemainAuthoredAndMatchSelectors() throws {
        // コンディション：document sectionとtable containerをすべて明示したHTMLがある（Given）
        let html = """
        <!doctype html><html id="root"><head><title>Explicit</title></head><body>
        <main id="app"><table id="metrics"><colgroup id="columns"><col id="metric-column"></colgroup><tbody id="rows"><tr id="metric-row"><td>42</td></tr></tbody></table></main>
        </body></html>
        """
        let css = OpenGraphiteCompanionCSSDocument(css: """
        :root { --tone: navy; }
        html > body > main { color: var(--tone); }
        table > colgroup > col { width: 42px; }
        table > tbody > tr { background: white; }
        """)

        // 検証内容：explicit構造をsource graphとCSS評価木へ読み込む（When）
        let nodes = OpenGraphiteHTMLDocument(html: html).nodes(
            companionCSS: css,
            documentURL: "file:///explicit.html"
        )
        let htmlNode = try #require(nodes.first { $0.tagName == "html" })
        let body = try #require(nodes.first { $0.tagName == "body" })
        let main = try #require(nodes.first { $0.attributes["id"] == "app" })
        let table = try #require(nodes.first { $0.attributes["id"] == "metrics" })
        let colgroup = try #require(nodes.first { $0.attributes["id"] == "columns" })
        let column = try #require(nodes.first { $0.attributes["id"] == "metric-column" })
        let tbody = try #require(nodes.first { $0.attributes["id"] == "rows" })
        let row = try #require(nodes.first { $0.attributes["id"] == "metric-row" })

        // 期待値：全sectionは1度だけgraphへ現れ、authored parentと標準selector resultを保つ（Then）
        #expect(nodes.filter { $0.tagName == "html" }.count == 1)
        #expect(nodes.filter { $0.tagName == "body" }.count == 1)
        #expect(nodes.filter { $0.tagName == "colgroup" }.count == 1)
        #expect(nodes.filter { $0.tagName == "tbody" }.count == 1)
        #expect(body.parentReference == htmlNode.reference)
        #expect(main.parentReference == body.reference)
        #expect(colgroup.parentReference == table.reference)
        #expect(column.parentReference == colgroup.reference)
        #expect(tbody.parentReference == table.reference)
        #expect(row.parentReference == tbody.reference)
        #expect(main.cssResolvedValues["color"] == "navy")
        #expect(column.cssResolvedValues["width"] == "42px")
        #expect(row.cssResolvedValues["background"] == "white")
    }

    /// 論理名（日本語）: Agent Core implicit DOM cascade parityテスト
    /// 概要: CLI / MCPが共有するpage graph入口でもbrowser CSS projectionを使い、読み取りだけではHTMLを書き換えないことを確認します。
    @Test("Agent Core graphはomitted rootとimplicit table cascadeを共有する")
    func testAgentCoreGraphUsesImplicitBrowserDOMCascadeWithoutWritingSource() throws {
        // コンディション：omitted root/implicit tbodyを持つ一時HTMLと同名companion CSSがある（Given）
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenGraphiteCSSDOMParity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let htmlURL = directory.appendingPathComponent("parity.html")
        let cssURL = directory.appendingPathComponent("parity.css")
        let html = "<main id=\"app\"><table><tr id=\"row\"><td>42</td></tr></table></main>"
        let css = """
        :root { --tone: rgb(9, 8, 7); }
        html > body > main { color: var(--tone); }
        table > tr { background: red; }
        table > tbody > tr { background: green; }
        """
        try html.write(to: htmlURL, atomically: true, encoding: .utf8)
        try css.write(to: cssURL, atomically: true, encoding: .utf8)

        // 検証内容：CLI / MCP共通のAgent Core page graph入口からnodeをinspectionする（When）
        let graph = try OpenGraphiteAgentCore(contract: .builtIn).pageGraph(at: htmlURL)
        let main = try #require(graph.nodes.first { $0.attributes["id"] == "app" })
        let row = try #require(graph.nodes.first { $0.attributes["id"] == "row" })

        // 期待値：標準selector/cascade resultが一致し、synthetic nodeやannotationの追記なしに元sourceが保持される（Then）
        #expect(graph.diagnostics.isEmpty)
        #expect(graph.nodes.map(\.tagName) == ["main", "table", "tr", "td"])
        #expect(main.cssResolvedValues["color"] == "rgb(9, 8, 7)")
        #expect(row.cssResolvedValues["background"] == "green")
        #expect(row.cssSourceTrace["background"]?.map(\.selector) == ["table > tbody > tr"])
        #expect(try String(contentsOf: htmlURL, encoding: .utf8) == html)
        #expect(graph.nodes.allSatisfy { node in
            !node.attributes.keys.contains { $0.hasPrefix("data-og-") }
        })
    }

    /// 論理名（日本語）: Migration observer semantic tokenテスト
    /// 概要: class/style attribute selectorと`attr()` readerをescape/comment/string/url境界込みで分類します。
    @Test("migration observerはCSS semantic tokenだけを検出する")
    func testMigrationObserverSemanticTokenBoundary() {
        // コンディション：functional class observer、escaped style reader、escaped attr()と非semantic文字列を用意する（Given）
        let unsafe = #"""
        .card:is([cl\61 ss$="frame"], .featured) { content: attr(cl\61 ss); }
        [style*="--migrated-v1-accent"] { color: red; }
        [style*="--o\67 -accent"] { color: blue; }
        .reader { content: attr(da\74 a-og-type); }
        """#
        let inert = #"""
        /* [class] [style*="--og-accent"] attr(data-og-type) */
        .keep {
          content: "[class] attr(data-og-type) --og-accent";
          background-image: url("attr(data-og-layout)--og-accent");
        }
        """#
        let wholeStyle = #"""
        [style^="--brand"], [style$="red"], [style*="color"] { outline: 0; }
        .reader { content: attr(st\79le); }
        """#
        let stylePresenceOnly = #"[style] { outline: 0; }"#

        // 検証内容：unsafe/inert CSSを明示migration observerへ通す（When）
        let unsafeResult = OpenGraphiteLegacyCSSMigrator.migrate(unsafe)
        let inertResult = OpenGraphiteLegacyCSSMigrator.migrate(inert)
        let wholeStyleResult = OpenGraphiteLegacyCSSMigrator.migrate(wholeStyle)
        let stylePresenceOnlyResult = OpenGraphiteLegacyCSSMigrator.migrate(stylePresenceOnly)

        // 期待値：semantic observerだけを列挙し、legacy readerはsource不変のblocking、comment/string/url単独はno-opにする（Then）
        #expect(unsafeResult.hasGeneratedClassObserver)
        #expect(unsafeResult.observedDestinationAttributes.contains("class"))
        #expect(unsafeResult.hasGeneratedCustomPropertyStyleObserver)
        #expect(unsafeResult.unsupportedLegacyConstructs.contains { $0.contains("legacy-inline-style-selector-reader") })
        #expect(unsafeResult.unsupportedLegacyConstructs.contains { $0.contains("legacy-attribute-function-reader:data-og-type") })
        #expect(unsafeResult.source == unsafe)
        #expect(!inertResult.detectedLegacy)
        #expect(!inertResult.hasGeneratedClassObserver)
        #expect(!inertResult.hasGeneratedCustomPropertyStyleObserver)
        #expect(inertResult.unsupportedLegacyConstructs.isEmpty)
        #expect(inertResult.source == inert)
        #expect(!wholeStyleResult.detectedLegacy)
        #expect(wholeStyleResult.hasGeneratedCustomPropertyStyleObserver)
        #expect(wholeStyleResult.unsupportedLegacyConstructs.isEmpty)
        #expect(wholeStyleResult.source == wholeStyle)
        #expect(!stylePresenceOnlyResult.hasGeneratedCustomPropertyStyleObserver)
        #expect(stylePresenceOnlyResult.source == stylePresenceOnly)
    }

    /// 論理名（日本語）: Migration CSS ASCII whitespace境界テスト
    /// 概要: NBSPをCSS identifierの一部として保持し、ASCII contract名へ誤正規化しません。
    @Test("migrationはNBSP custom propertyをreserved ASCII名へ誤認しない")
    func testMigrationDoesNotNormalizeNBSPIntoReservedCustomPropertyName() {
        // コンディション：literal/escapeのNBSPを末尾に持つcustom propertyと既知controlを用意する（Given）
        let nbsp = "\u{00A0}"
        let literal = ".probe{--og-text-color\(nbsp):red;color:var(--og-text-color\(nbsp));}"
        let escaped = #".probe{--og-text-color\A0 :red;color:var(--og-text-color\A0 );}"#
        let control = ".probe{--og-text-color:red;color:var(--og-text-color);}"

        // 検証内容：3 sourceをlossless migratorへ通す（When）
        let literalResult = OpenGraphiteLegacyCSSMigrator.migrate(literal)
        let escapedResult = OpenGraphiteLegacyCSSMigrator.migrate(escaped)
        let controlResult = OpenGraphiteLegacyCSSMigrator.migrate(control)

        // 期待値：NBSP付きidentifierはbyte保持し、exact ASCII contract名だけを変換する（Then）
        #expect(!literalResult.detectedLegacy)
        #expect(literalResult.unknownReservedProperties.isEmpty)
        #expect(literalResult.unsupportedLegacyConstructs.isEmpty)
        #expect(literalResult.source == literal)
        #expect(!escapedResult.detectedLegacy)
        #expect(escapedResult.unknownReservedProperties.isEmpty)
        #expect(escapedResult.unsupportedLegacyConstructs.isEmpty)
        #expect(escapedResult.source == escaped)
        #expect(controlResult.detectedLegacy)
        #expect(controlResult.source.contains("--migrated-v1-text-color"))
        #expect(!controlResult.source.contains("--og-text-color"))
    }
}

/// 論理名（日本語）: WebKit computed style分離テストスイート
/// 概要: WebKit描画値とCSS source provenanceを別々に取得して一致を確認します。
@MainActor
@Suite("WebKit computed style分離テストスイート")
struct OpenGraphiteComputedStyleIntegrationTests {
    /// 論理名（日本語）: WebKit computed style統合テスト
    /// 概要: standard selector、inheritance、custom property、mediaがWebKitとsource traceで同じ現在値になることを確認します。
    @Test("WebKit computed styleとsource cascade traceを分離して一致確認できる")
    func testWebKitComputedStyleMatchesActiveSourceTrace() async throws {
        // コンディション：標準selectorとcustom propertyを持つHTML/CSSをWebKitへ読み込む（Given）
        let css = """
        :root { --copy-color: rgb(12, 34, 56); }
        article { color: var(--copy-color); padding: 10px 18px; }
        article.featured { display: grid; }
        @media (max-width: 700px) { article.featured { display: block; } }
        """
        let html = """
        <!doctype html><html><head><style>\(css)</style></head>
        <body><article id="card" class="featured"><span>Card</span></article></body></html>
        """
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
        let waiter = CSSWebViewNavigationWaiter()
        try await waiter.load(html, in: webView)

        // 検証内容：WebKit computed styleとactive media付きsource traceを別々に取得する（When）
        let computed = try #require(try await webView.evaluateJavaScript(
            """
            (() => {
              const style = getComputedStyle(document.getElementById('card'));
              return { color: style.color, display: style.display, paddingLeft: style.paddingLeft };
            })()
            """
        ) as? [String: String])
        let root = OpenGraphiteCSSDOMElement(tagName: "html", isRoot: true)
        let document = OpenGraphiteCSSSourceDocument.parse(css)
        let rootTrace = document.cascadeTrace(for: root)
        let article = OpenGraphiteCSSDOMElement(
            tagName: "article",
            attributes: ["id": "card", "class": "featured"],
            ancestors: [OpenGraphiteCSSDOMElement(tagName: "body"), root]
        )
        let trace = document.cascadeTrace(
            for: article,
            inheritedValues: rootTrace.resolvedValues,
            environment: OpenGraphiteCSSCascadeEnvironment(
                activeMediaQueries: ["(max-width: 700px)"],
                includeUnknownConditionalRules: false
            )
        )

        // 期待値：computed値はsource traceのresolved値と一致し、traceはauthored provenanceも保持する（Then）
        #expect(computed["color"] == "rgb(12, 34, 56)")
        #expect(computed["display"] == "block")
        #expect(computed["paddingLeft"] == "18px")
        #expect(trace.resolvedValues["color"] == "rgb(12, 34, 56)")
        #expect(trace.resolvedValues["display"] == "block")
        #expect(trace.resolvedValues["padding-left"] == "18px")
        #expect(trace.winners["display"]?.atRules.first?.name == "media")
    }

    /// 論理名（日本語）: Escaped CSS identifier WebKit parityテスト
    /// 概要: property、priority、selector、custom propertyのescapeをShared source traceとWebKitで同じsemantic値へ評価します。
    @Test("escaped CSS identifierのsource traceはWebKit computed styleと一致する")
    func testEscapedCSSIdentifiersMatchWebKitComputedStyle() async throws {
        // コンディション：hex/simple escapeをproperty、important、class、ID、type、custom propertyへ使うHTML/CSSがある（Given）
        let css = #"""
        :root { --c\6f lor: rgb(90, 80, 70); }
        .c\61 rd.foo\+bar#hero\+id { co\lor: rgb(12, 34, 56) !\69mportant; }
        #hero\+id { color: rgb(1, 2, 3); }
        custom\2d element { background-color: var(--c\6f lor); }
        """#
        let html = """
        <!doctype html><html><head><style>\(css)</style></head>
        <body><custom-element id="hero+id" class="card foo+bar">Card</custom-element></body></html>
        """
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
        let waiter = CSSWebViewNavigationWaiter()
        try await waiter.load(html, in: webView)

        // 検証内容：WebKit computed styleとSharedのdecoded source cascadeをそれぞれ取得する（When）
        let computed = try #require(try await webView.evaluateJavaScript(
            """
            (() => {
              const style = getComputedStyle(document.getElementById('hero+id'));
              return { color: style.color, backgroundColor: style.backgroundColor };
            })()
            """
        ) as? [String: String])
        let root = OpenGraphiteCSSDOMElement(tagName: "html", isRoot: true)
        let document = OpenGraphiteCSSSourceDocument.parse(css)
        let rootTrace = document.cascadeTrace(for: root)
        let element = OpenGraphiteCSSDOMElement(
            tagName: "custom-element",
            attributes: ["id": "hero+id", "class": "card foo+bar"],
            ancestors: [OpenGraphiteCSSDOMElement(tagName: "body"), root]
        )
        let trace = document.cascadeTrace(for: element, inheritedValues: rootTrace.resolvedValues)

        // 期待値：decoded selectorとpriorityのwinner、escaped var解決値、computed styleが同じになり、raw selector provenanceも残る（Then）
        #expect(computed["color"] == "rgb(12, 34, 56)")
        #expect(computed["backgroundColor"] == "rgb(90, 80, 70)")
        #expect(trace.resolvedValues["color"] == "rgb(12, 34, 56)")
        #expect(trace.resolvedValues["background-color"] == "rgb(90, 80, 70)")
        #expect(trace.winners["color"]?.selector == #".c\61 rd.foo\+bar#hero\+id"#)
        #expect(trace.winners["background-color"]?.selector == #"custom\2d element"#)
        #expect(document.source == css)
    }

    /// 論理名（日本語）: Selector comment WebKit parityテスト
    /// 概要: comment内のselector delimiterを無視するShared lexerとWebKit computed styleの一致を確認します。
    @Test("selector commentを含むsource cascadeはWebKit computed styleと一致する")
    func testSelectorCommentSourceTraceMatchesWebKit() async throws {
        // コンディション：comma、space、child combinatorを含むcomment付きclass selectorと標準HTMLがある（Given）
        let css = ".card/* keep, > */ { color: rgb(21, 43, 65); }"
        let html = """
        <!doctype html><html><head><style>\(css)</style></head>
        <body><article id="card" class="card">Card</article></body></html>
        """
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
        let waiter = CSSWebViewNavigationWaiter()
        try await waiter.load(html, in: webView)

        // 検証内容：WebKit computed colorとShared source traceを別々に取得する（When）
        let computedColor = try #require(try await webView.evaluateJavaScript(
            "getComputedStyle(document.getElementById('card')).color"
        ) as? String)
        let document = OpenGraphiteCSSSourceDocument.parse(css)
        let element = OpenGraphiteCSSDOMElement(
            tagName: "article",
            attributes: ["id": "card", "class": "card"]
        )
        let trace = document.cascadeTrace(for: element)

        // 期待値：両評価面でcomment外のclass selectorが一致し、source provenanceとcomment bytesはauthoredのまま残る（Then）
        #expect(computedColor == "rgb(21, 43, 65)")
        #expect(trace.resolvedValues["color"] == "rgb(21, 43, 65)")
        #expect(trace.winners["color"]?.selector == ".card/* keep, > */")
        #expect(document.source == css)
    }

    /// 論理名（日本語）: Escaped attribute selector WebKit parityテスト
    /// 概要: attribute identifier/string escapeとcase modifierのShared評価をWebKit computed styleと比較します。
    @Test("escaped attribute selector modifierのsource traceはWebKitと一致する")
    func testEscapedAttributeSelectorModifiersMatchWebKit() async throws {
        // コンディション：同じescaped attribute selectorをi/s modifierで比較するHTML/CSSがある（Given）
        let css = #"""
        [data\2d label="a\+b" i] { color: rgb(31, 63, 95); }
        [data\2d label="a\+b" s] { background-color: rgb(7, 8, 9); }
        """#
        let html = """
        <!doctype html><html><head><style>\(css)</style></head>
        <body><article id="card" data-label="A+B">Card</article></body></html>
        """
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
        let waiter = CSSWebViewNavigationWaiter()
        try await waiter.load(html, in: webView)

        // 検証内容：WebKit computed styleとShared source cascadeを同じauthored selectorから取得する（When）
        let computed = try #require(try await webView.evaluateJavaScript(
            """
            (() => {
              const style = getComputedStyle(document.getElementById('card'));
              return { color: style.color, backgroundColor: style.backgroundColor };
            })()
            """
        ) as? [String: String])
        let document = OpenGraphiteCSSSourceDocument.parse(css)
        let element = OpenGraphiteCSSDOMElement(
            tagName: "article",
            attributes: ["id": "card", "data-label": "A+B"]
        )
        let trace = document.cascadeTrace(for: element)

        // 期待値：ASCII-insensitive ruleだけが両評価面で一致し、case-sensitive ruleとsource bytesはそのまま残る（Then）
        #expect(computed["color"] == "rgb(31, 63, 95)")
        #expect(computed["backgroundColor"] == "rgba(0, 0, 0, 0)")
        #expect(trace.resolvedValues["color"] == "rgb(31, 63, 95)")
        #expect(trace.resolvedValues["background-color"] == nil)
        #expect(trace.winners["color"]?.selector == #"[data\2d label="a\+b" i]"#)
        #expect(document.source == css)
    }

    /// 論理名（日本語）: Standard hidden UA fallback WebKit parityテスト
    /// 概要: `hidden`のsource intentとUA `display:none` fallbackを分離し、author displayと大文字小文字を問わない`until-found`をWebKit結果に合わせます。
    @Test("standard hiddenのUA fallbackとauthor displayはWebKitと一致する")
    func testStandardHiddenFallbackAndAuthoredDisplayMatchWebKit() async throws {
        // コンディション：bare hidden、author display override、lowercase/mixed-caseのuntil-foundを同じdocumentに用意する（Given）
        let sourceHTML = """
        <!doctype html><html><body>
          <div id="bare" hidden>Bare</div>
          <section id="typed-bare" hidden>Typed bare</section>
          <button id="typed-button" hidden>Typed button</button>
          <force-box id="forced" hidden>Forced</force-box>
          <section id="until-lower" hidden="until-found">Lowercase findable</section>
          <section id="until-mixed" hidden="UNTIL-FOUND">Mixed-case findable</section>
        </body></html>
        """
        let authoredCSS = "force-box { display: block; }"
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
        let waiter = CSSWebViewNavigationWaiter()
        try await waiter.load(
            sourceHTML.replacingOccurrences(of: "<body>", with: "<head><style>\(authoredCSS)</style></head><body>"),
            in: webView
        )

        // 検証内容：WebKit computed displayとShared source graph、配布OpenGraphite.css追加時のwinnerをそれぞれ取得する（When）
        let authoredComputed = try #require(try await webView.evaluateJavaScript(
            """
            (() => ({
              bare: getComputedStyle(document.getElementById('bare')).display,
              typedBare: getComputedStyle(document.getElementById('typed-bare')).display,
              typedButton: getComputedStyle(document.getElementById('typed-button')).display,
              forced: getComputedStyle(document.getElementById('forced')).display,
              untilLower: getComputedStyle(document.getElementById('until-lower')).display,
              untilMixed: getComputedStyle(document.getElementById('until-mixed')).display
            }))()
            """
        ) as? [String: String])
        let authoredNodes = OpenGraphiteHTMLDocument(html: sourceHTML).nodes(
            companionCSS: OpenGraphiteCompanionCSSDocument(css: authoredCSS),
            documentURL: "file:///hidden-parity.html"
        )
        let bare = try #require(authoredNodes.first { $0.attributes["id"] == "bare" })
        let typedBare = try #require(authoredNodes.first { $0.attributes["id"] == "typed-bare" })
        let typedButton = try #require(authoredNodes.first { $0.attributes["id"] == "typed-button" })
        let forced = try #require(authoredNodes.first { $0.attributes["id"] == "forced" })
        let untilLower = try #require(authoredNodes.first { $0.attributes["id"] == "until-lower" })
        let untilMixed = try #require(authoredNodes.first { $0.attributes["id"] == "until-mixed" })
        let contractURL = try #require(OpenGraphiteContract.findContractURL(
            startingAt: URL(fileURLWithPath: #filePath)
        ))
        let distributedCSS = try String(
            contentsOf: contractURL.deletingLastPathComponent().appendingPathComponent("CSS/OpenGraphite.css"),
            encoding: .utf8
        )
        let distributedSource = distributedCSS + "\n" + authoredCSS
        try await waiter.load(
            sourceHTML.replacingOccurrences(
                of: "<body>",
                with: "<head><style>\(distributedSource)</style></head><body>"
            ),
            in: webView
        )
        let distributedComputed = try #require(try await webView.evaluateJavaScript(
            """
            (() => ({
              bare: getComputedStyle(document.getElementById('bare')).display,
              typedBare: getComputedStyle(document.getElementById('typed-bare')).display,
              typedButton: getComputedStyle(document.getElementById('typed-button')).display,
              forced: getComputedStyle(document.getElementById('forced')).display,
              untilLower: getComputedStyle(document.getElementById('until-lower')).display,
              untilMixed: getComputedStyle(document.getElementById('until-mixed')).display
            }))()
            """
        ) as? [String: String])
        let distributedNodes = OpenGraphiteHTMLDocument(html: sourceHTML).nodes(
            companionCSS: OpenGraphiteCompanionCSSDocument(css: distributedSource),
            documentURL: "file:///hidden-distributed-parity.html"
        )
        let distributedBare = try #require(distributedNodes.first { $0.attributes["id"] == "bare" })
        let distributedTypedBare = try #require(distributedNodes.first { $0.attributes["id"] == "typed-bare" })
        let distributedTypedButton = try #require(distributedNodes.first { $0.attributes["id"] == "typed-button" })
        let distributedForced = try #require(distributedNodes.first { $0.attributes["id"] == "forced" })
        let distributedUntilLower = try #require(distributedNodes.first { $0.attributes["id"] == "until-lower" })
        let distributedUntilMixed = try #require(distributedNodes.first { $0.attributes["id"] == "until-mixed" })
        let unhiddenButtonDisplay = try #require(try await webView.evaluateJavaScript(
            """
            (() => {
              const button = document.getElementById('typed-button');
              button.removeAttribute('hidden');
              return getComputedStyle(button).display;
            })()
            """
        ) as? String)
        let unhiddenHTML = sourceHTML.replacingOccurrences(
            of: #"id="typed-button" hidden"#,
            with: #"id="typed-button""#
        )
        let unhiddenNodes = OpenGraphiteHTMLDocument(html: unhiddenHTML).nodes(
            companionCSS: OpenGraphiteCompanionCSSDocument(css: distributedSource),
            documentURL: "file:///hidden-distributed-parity.html"
        )
        let unhiddenTypedButton = try #require(unhiddenNodes.first { $0.attributes["id"] == "typed-button" })

        // 期待値：bareだけUA fallbackでnoneとなり、author displayと両表記のuntil-foundは配布CSSでもblockを維持する（Then）
        #expect(bare.hidden == true)
        #expect(typedBare.hidden == true)
        #expect(typedButton.hidden == true)
        #expect(forced.hidden == true)
        #expect(untilLower.hidden == true)
        #expect(untilMixed.hidden == true)
        #expect(bare.cssResolvedValues["display"] == "none")
        #expect(typedBare.cssResolvedValues["display"] == "none")
        #expect(typedButton.cssResolvedValues["display"] == "none")
        #expect(forced.cssResolvedValues["display"] == "block")
        #expect(untilLower.cssResolvedValues["display"] == "block")
        #expect(untilMixed.cssResolvedValues["display"] == "block")
        #expect(authoredComputed["bare"] == bare.cssResolvedValues["display"])
        #expect(authoredComputed["typedBare"] == typedBare.cssResolvedValues["display"])
        #expect(authoredComputed["typedButton"] == typedButton.cssResolvedValues["display"])
        #expect(authoredComputed["forced"] == forced.cssResolvedValues["display"])
        #expect(authoredComputed["untilLower"] == untilLower.cssResolvedValues["display"])
        #expect(authoredComputed["untilMixed"] == untilMixed.cssResolvedValues["display"])
        #expect(distributedBare.cssResolvedValues["display"] == "none")
        #expect(distributedTypedBare.cssResolvedValues["display"] == "none")
        #expect(distributedTypedButton.cssResolvedValues["display"] == "none")
        #expect(distributedForced.hidden == true)
        #expect(distributedForced.cssResolvedValues["display"] == "block")
        #expect(distributedUntilLower.cssResolvedValues["display"] == "block")
        #expect(distributedUntilMixed.cssResolvedValues["display"] == "block")
        #expect(distributedComputed["bare"] == distributedBare.cssResolvedValues["display"])
        #expect(distributedComputed["typedBare"] == distributedTypedBare.cssResolvedValues["display"])
        #expect(distributedComputed["typedButton"] == distributedTypedButton.cssResolvedValues["display"])
        #expect(distributedComputed["forced"] == distributedForced.cssResolvedValues["display"])
        #expect(distributedComputed["untilLower"] == distributedUntilLower.cssResolvedValues["display"])
        #expect(distributedComputed["untilMixed"] == distributedUntilMixed.cssResolvedValues["display"])
        #expect(unhiddenTypedButton.hidden == false)
        #expect(unhiddenTypedButton.cssResolvedValues["display"] == "inline-block")
        #expect(unhiddenButtonDisplay == unhiddenTypedButton.cssResolvedValues["display"])
        #expect(distributedForced.cssSourceTrace["display"]?.contains {
            $0.selector.contains("hidden")
        } != true)
    }

    /// 論理名（日本語）: Media conditionText WebKit parityテスト
    /// 概要: authored media punctuation/range/caseをraw traceに保ちつつ、CSSOM `conditionText`をactive照合keyとして使えることを確認します。
    @Test("media source preludeはCSSOM conditionTextでactive照合できる")
    func testMediaSourcePreludeMatchesCSSOMConditionText() async throws {
        // コンディション：colon空白のない条件とuppercase range featureを持つresponsive CSSを用意する（Given）
        let css = """
        @media (min-width:500px) { #target { color: rgb(10, 20, 30); } }
        @media (400px<WIDTH<=1000px) { #target { background-color: rgb(40, 50, 60); } }
        """
        let html = """
        <!doctype html><html><head><style>\(css)</style></head>
        <body><div id="target">Target</div></body></html>
        """
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
        let waiter = CSSWebViewNavigationWaiter()
        try await waiter.load(html, in: webView)

        // 検証内容：WebKitがcanonicalizeしたconditionTextをそのままSharedのactive environmentへ渡す（When）
        let browser = try #require(try await webView.evaluateJavaScript(
            """
            (() => {
              const style = getComputedStyle(document.getElementById('target'));
              return {
                conditions: Array.from(document.styleSheets[0].cssRules).map(rule => rule.conditionText),
                color: style.color,
                backgroundColor: style.backgroundColor
              };
            })()
            """
        ) as? [String: Any])
        let conditions = try #require(browser["conditions"] as? [String])
        let trace = OpenGraphiteCSSSourceDocument.parse(css).cascadeTrace(
            for: OpenGraphiteCSSDOMElement(tagName: "div", attributes: ["id": "target"]),
            environment: .inspection(activeMediaQueries: conditions)
        )

        // 期待値：CSSOM keyで両ruleがactiveになり、trace preludeはauthored bytesの表記を保つ（Then）
        #expect(conditions == ["(min-width: 500px)", "(400px < width <= 1000px)"])
        #expect(browser["color"] as? String == "rgb(10, 20, 30)")
        #expect(browser["backgroundColor"] as? String == "rgb(40, 50, 60)")
        #expect(trace.resolvedValues["color"] == (browser["color"] as? String))
        #expect(trace.resolvedValues["background-color"] == (browser["backgroundColor"] as? String))
        #expect(trace.winners["color"]?.atRules.first?.prelude == "(min-width:500px)")
        #expect(trace.winners["background-color"]?.atRules.first?.prelude == "(400px<WIDTH<=1000px)")
    }

    /// 論理名（日本語）: Browser implicit DOM computed style parityテスト
    /// 概要: omitted document sectionとimplicit table containerについて、Shared source traceと隔離WKWebViewのDOM/cascade結果を比較します。
    @Test("omitted rootとimplicit table containerのsource cascadeはWebKitと一致する")
    func testImplicitBrowserDOMSourceTraceMatchesWebKit() async throws {
        // コンディション：omitted rootとimplicit colgroup/tbodyを持つHTML/CSSを用意する（Given）
        let css = """
        :root { --tone: rgb(11, 22, 33); }
        body main { color: var(--tone); }
        html > body > main { background: rgb(44, 55, 66); }
        table > col { width: 1px; }
        table > colgroup > col { width: 42px; }
        table > tr { color: rgb(1, 1, 1); }
        table > tbody > tr { color: rgb(2, 3, 4); }
        """
        let sourceHTML = """
        <!doctype html><style>\(css)</style>
        <main id="app"><table><col id="metric-column"><tr id="metric-row"><td>42</td></tr></table></main>
        """
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
        let waiter = CSSWebViewNavigationWaiter()
        try await waiter.load(sourceHTML, in: webView)

        // 検証内容：WebKitの実DOM/computed styleとSharedのsource-backed graphを別々に取得する（When）
        let browser = try #require(try await webView.evaluateJavaScript(
            """
            (() => {
              const main = document.getElementById('app');
              const column = document.getElementById('metric-column');
              const row = document.getElementById('metric-row');
              return {
                mainParent: main.parentElement.tagName.toLowerCase(),
                rowParent: row.parentElement.tagName.toLowerCase(),
                columnParent: column.parentElement.tagName.toLowerCase(),
                mainColor: getComputedStyle(main).color,
                mainBackground: getComputedStyle(main).backgroundColor,
                rowColor: getComputedStyle(row).color,
                directRowMatch: row.matches('table > tr'),
                tbodyRowMatch: row.matches('table > tbody > tr'),
                colgroupMatch: column.matches('table > colgroup > col')
              };
            })()
            """
        ) as? [String: Any])
        let nodes = OpenGraphiteHTMLDocument(html: sourceHTML).nodes(
            companionCSS: OpenGraphiteCompanionCSSDocument(css: css),
            documentURL: "file:///webkit-parity.html"
        )
        let main = try #require(nodes.first { $0.attributes["id"] == "app" })
        let column = try #require(nodes.first { $0.attributes["id"] == "metric-column" })
        let row = try #require(nodes.first { $0.attributes["id"] == "metric-row" })

        // 期待値：WebKitが補ったDOM構造とcomputed値がShared projectionのselector/resolved値に一致する（Then）
        #expect(browser["mainParent"] as? String == "body")
        #expect(browser["rowParent"] as? String == "tbody")
        #expect(browser["columnParent"] as? String == "colgroup")
        #expect(browser["directRowMatch"] as? Bool == false)
        #expect(browser["tbodyRowMatch"] as? Bool == true)
        #expect(browser["colgroupMatch"] as? Bool == true)
        #expect(browser["mainColor"] as? String == main.cssResolvedValues["color"])
        #expect(browser["mainBackground"] as? String == main.cssResolvedValues["background"])
        #expect(browser["rowColor"] as? String == row.cssResolvedValues["color"])
        #expect(column.cssResolvedValues["width"] == "42px")
    }

    /// 論理名（日本語）: CSS-wide keyword WebKit parityテスト
    /// 概要: authored keyword provenanceを保持しつつ、inherit/initial/unsetとcustom propertyのguaranteed-invalid値をcomputed semanticsへ解決します。
    @Test("CSS-wide keywordとcustom property initialはWebKit semanticsへ解決する")
    func testCSSWideKeywordsAndCustomPropertyInitialMatchWebKit() async throws {
        // コンディション：親継承値、非継承propertyのinherit、継承propertyのinitial、custom property initial/revertを持つHTML/CSSを用意する（Given）
        let css = """
        .parent { display: flex; visibility: hidden; overflow-wrap: anywhere; --tone: initial; }
        .child { display: inherit; visibility: initial; color: var(--tone, rgb(12, 34, 56)); }
        .revert-inherited { visibility: revert; overflow-wrap: revert-layer; }
        .revert { display: grid; display: revert; }
        .revert-layer { display: grid; display: revert-layer; }
        """
        let html = """
        <!doctype html><html><head><style>\(css)</style></head><body>
          <section class="parent"><span id="child" class="child">Child</span><span id="revert-inherited" class="revert-inherited">Inherited revert</span></section>
          <span id="revert" class="revert">Revert</span>
          <span id="revert-layer" class="revert-layer">Revert layer</span>
        </body></html>
        """
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
        let waiter = CSSWebViewNavigationWaiter()
        try await waiter.load(html, in: webView)

        // 検証内容：browser computed styleとShared source graphを同じsourceから取得する（When）
        let computed = try #require(try await webView.evaluateJavaScript(
            """
            (() => {
              const child = getComputedStyle(document.getElementById('child'));
              return {
                childDisplay: child.display,
                childVisibility: child.visibility,
                childColor: child.color,
                revertInheritedVisibility: getComputedStyle(document.getElementById('revert-inherited')).visibility,
                revertInheritedWrap: getComputedStyle(document.getElementById('revert-inherited')).overflowWrap,
                revertDisplay: getComputedStyle(document.getElementById('revert')).display,
                revertLayerDisplay: getComputedStyle(document.getElementById('revert-layer')).display
              };
            })()
            """
        ) as? [String: String])
        let nodes = OpenGraphiteHTMLDocument(html: html).nodes(
            companionCSS: OpenGraphiteCompanionCSSDocument(css: css),
            documentURL: "file:///css-wide.html"
        )
        let child = try #require(nodes.first { $0.attributes["id"] == "child" })
        let revertInherited = try #require(nodes.first { $0.attributes["id"] == "revert-inherited" })
        let revert = try #require(nodes.first { $0.attributes["id"] == "revert" })
        let revertLayer = try #require(nodes.first { $0.attributes["id"] == "revert-layer" })

        // 期待値：resolved値だけを標準computed semanticsへ寄せ、raw keywordと安全不能なrevert境界を残す（Then）
        #expect(child.cssVariables["display"] == "inherit")
        #expect(child.cssVariables["visibility"] == "initial")
        #expect(child.cssResolvedValues["display"] == computed["childDisplay"])
        #expect(child.cssResolvedValues["visibility"] == computed["childVisibility"])
        #expect(child.cssResolvedValues["color"] == computed["childColor"])
        #expect(revertInherited.cssResolvedValues["visibility"] == computed["revertInheritedVisibility"])
        #expect(revertInherited.cssResolvedValues["overflow-wrap"] == computed["revertInheritedWrap"])
        #expect(revertInherited.hasIncompleteCSSProvenance == true)
        #expect(revert.cssVariables["display"] == "revert")
        #expect(revert.cssResolvedValues["display"] == computed["revertDisplay"])
        #expect(revert.hasIncompleteCSSProvenance == true)
        #expect(revertLayer.cssVariables["display"] == "revert-layer")
        #expect(revertLayer.cssResolvedValues["display"] == computed["revertLayerDisplay"])
        #expect(revertLayer.hasIncompleteCSSProvenance == true)
    }

    /// 論理名（日本語）: Var-backed shorthand WebKit parityテスト
    /// 概要: multi-token custom propertyを参照するflex-flow、gap、marginのcomputed longhandをWebKitへ合わせます。
    @Test("var-backed flex-flow gap marginのlonghand解決はWebKitと一致する")
    func testVariableBackedShorthandLonghandsMatchWebKit() async throws {
        // コンディション：3種類のmulti-token shorthandをcustom property経由で指定するHTML/CSSを用意する（Given）
        let css = """
        .panel {
          --flow: column wrap;
          --space: 8px 12px;
          --edges: 1px 2px 3px 4px;
          display: flex;
          flex-flow: var(--flow);
          gap: var(--space);
          margin: var(--edges);
        }
        """
        let html = "<!doctype html><html><head><style>\(css)</style></head><body><section id=\"panel\" class=\"panel\"></section></body></html>"
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
        let waiter = CSSWebViewNavigationWaiter()
        try await waiter.load(html, in: webView)

        // 検証内容：WebKit computed styleとShared source graphを取得する（When）
        let computed = try #require(try await webView.evaluateJavaScript(
            """
            (() => {
              const style = getComputedStyle(document.getElementById('panel'));
              return {
                direction: style.flexDirection,
                wrap: style.flexWrap,
                gap: style.gap,
                rowGap: style.rowGap,
                columnGap: style.columnGap,
                margin: style.margin,
                marginTop: style.marginTop,
                marginRight: style.marginRight,
                marginBottom: style.marginBottom,
                marginLeft: style.marginLeft
              };
            })()
            """
        ) as? [String: String])
        let document = OpenGraphiteHTMLDocument(html: html)
        let documentURL = URL(fileURLWithPath: "/var-shorthand.html")
        let stylesheets = document.stylesheetResolution(documentURL: documentURL)
        let sourceTrace = OpenGraphiteCSSSourceDocument.cascadeTrace(
            for: OpenGraphiteCSSDOMElement(tagName: "section", attributes: ["id": "panel", "class": "panel"]),
            stylesheets: stylesheets.sources
        )
        let panel = try #require(
            document.nodes(
                stylesheetSources: stylesheets.sources,
                hasIncompleteCSSProvenance: stylesheets.hasIncompleteProvenance,
                documentURL: documentURL.absoluteString
            ).first { $0.attributes["id"] == "panel" }
        )

        // 期待値：全longhand computed値が一致し、source traceはraw var shorthandへ戻れる（Then）
        #expect(panel.cssResolvedValues["flex-direction"] == computed["direction"])
        #expect(panel.cssResolvedValues["flex-wrap"] == computed["wrap"])
        #expect(panel.cssResolvedValues["gap"] == computed["gap"])
        #expect(panel.cssResolvedValues["margin"] == computed["margin"])
        #expect(sourceTrace.resolvedValues["row-gap"] == computed["rowGap"])
        #expect(sourceTrace.resolvedValues["column-gap"] == computed["columnGap"])
        #expect(sourceTrace.resolvedValues["margin-top"] == computed["marginTop"])
        #expect(sourceTrace.resolvedValues["margin-right"] == computed["marginRight"])
        #expect(sourceTrace.resolvedValues["margin-bottom"] == computed["marginBottom"])
        #expect(sourceTrace.resolvedValues["margin-left"] == computed["marginLeft"])
        #expect(panel.cssSourceTrace["flex-direction"]?.last?.authoredProperty == "flex-flow")
        #expect(panel.cssSourceTrace["flex-direction"]?.last?.value == "var(--flow)")
        #expect(panel.hasIncompleteCSSProvenance == false)
    }

    /// 論理名（日本語）: Geometry・track CSSOM受理境界テスト
    /// 概要: Shared grammarが解決する標準値と不完全扱いするinvalid値を、WebKit CSSOMのdeclaration受理結果へ照合します。
    @Test("geometryとtrack grammarの受理境界はWebKit CSSOMと一致する")
    func testGeometryAndTrackGrammarAcceptanceMatchesWebKitCSSOM() async throws {
        // コンディション：valid/invalidなgeometry、math、grid track declarationを別ruleへ記述する（Given）
        let css = """
        .valid {
          gap: normal 2cqw;
          width: min(100%, 60rem);
          inset: clamp(-2rem, 0px, 3rem) auto;
          grid-template-columns: [start] minmax(0px, 1fr) repeat(2, fit-content(12ch));
          grid-auto-rows: minmax(0, 1fr);
          stroke-width: calc(1 + 1);
          z-index: calc(1 + 1);
          scale: calc(100% - 10%) calc(1 + .2);
          line-height: calc(1 + .2);
        }
        .invalid {
          gap: nonsense;
          width: min();
          inset: 0 0 0 0 0;
          grid-template-columns: repeat(nonsense);
          grid-auto-rows: minmax(nonsense, 1fr);
          stroke-width: calc(nonsense);
          z-index: 1.5;
          scale: calc(1px);
          scale: calc(100% - 1px);
          scale: calc(100% - .2);
          line-height: calc(1 + 1px);
        }
        """
        let properties = [
            "gap", "width", "inset", "grid-template-columns", "grid-auto-rows",
            "stroke-width", "z-index", "scale", "line-height"
        ]
        let html = "<!doctype html><style>\(css)</style><section class=valid></section><section class=invalid></section>"
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
        let waiter = CSSWebViewNavigationWaiter()
        try await waiter.load(html, in: webView)

        // 検証内容：WebKit CSSStyleDeclarationの受理値とShared source cascadeを取得する（When）
        let javascriptProperties = properties.map { "'\($0)'" }.joined(separator: ",")
        let browser = try #require(try await webView.evaluateJavaScript(
            """
            (() => {
              const properties = [\(javascriptProperties)];
              const valid = document.styleSheets[0].cssRules[0].style;
              const invalid = document.styleSheets[0].cssRules[1].style;
              return {
                valid: Object.fromEntries(properties.map(property => [property, valid.getPropertyValue(property)])),
                invalid: Object.fromEntries(properties.map(property => [property, invalid.getPropertyValue(property)]))
              };
            })()
            """
        ) as? [String: [String: String]])
        let document = OpenGraphiteCSSSourceDocument.parse(css)
        let valid = document.cascadeTrace(
            for: OpenGraphiteCSSDOMElement(tagName: "section", attributes: ["class": "valid"])
        )
        let invalid = document.cascadeTrace(
            for: OpenGraphiteCSSDOMElement(tagName: "section", attributes: ["class": "invalid"])
        )

        // 期待値：browserが受理したruleだけをSharedも解決し、破棄したruleはproperty単位でwrite blockにする（Then）
        for property in properties {
            #expect(browser["valid"]?[property]?.isEmpty == false, "WebKit rejected valid \(property)")
            #expect(browser["invalid"]?[property]?.isEmpty == true, "WebKit accepted invalid \(property)")
        }
        #expect(valid.incompleteProperties.isEmpty)
        #expect(invalid.incompleteProperties.isSuperset(of: Set(properties)))
        #expect(document.source == css)
    }

    /// 論理名（日本語）: Flex/Grid shorthand simple-blockテスト
    /// 概要: comment、quoted slash、named line、simple blockを境界にせずflex-flow/grid-templateをlonghandへ展開します。
    @Test("flex-flowとgrid-templateはcommentとsimple blockを保持して展開する")
    func testFlexFlowAndGridTemplateExpandWithSimpleBlocks() async throws {
        // コンディション：comment区切りflex-flowとquoted slash/comment/named lineを含むgrid-template shorthandがある（Given）
        let css = #"""
        .flex { display: flex; flex-flow: column/**/wrap; }
        .grid { display: grid; grid-template: [row-start] "hero copy" minmax(0, 1fr) /* slash / stays */ / [col-start] 1fr 2fr; }
        .invalid { display: grid; grid-template: "hero / copy" / 1fr 1fr; }
        """#
        let document = OpenGraphiteCSSSourceDocument.parse(css)
        let html = "<!doctype html><style>\(css)</style><section class=\"flex\"></section><section class=\"grid\"></section>"
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
        let waiter = CSSWebViewNavigationWaiter()
        try await waiter.load(html, in: webView)

        // 検証内容：各selectorのsource cascadeを評価する（When）
        let flex = document.cascadeTrace(
            for: OpenGraphiteCSSDOMElement(tagName: "section", attributes: ["class": "flex"])
        )
        let grid = document.cascadeTrace(
            for: OpenGraphiteCSSDOMElement(tagName: "section", attributes: ["class": "grid"])
        )
        let invalid = document.cascadeTrace(
            for: OpenGraphiteCSSDOMElement(tagName: "section", attributes: ["class": "invalid"])
        )
        let browser = try #require(try await webView.evaluateJavaScript(
            """
            (() => {
              const flex = document.styleSheets[0].cssRules[0].style;
              const grid = document.styleSheets[0].cssRules[1].style;
              return {
                flexDirection: flex.flexDirection,
                flexWrap: flex.flexWrap,
                gridRows: grid.gridTemplateRows,
                gridColumns: grid.gridTemplateColumns,
                invalidRows: document.styleSheets[0].cssRules[2].style.gridTemplateRows
              };
            })()
            """
        ) as? [String: String])

        // 期待値：semantic longhandだけが展開され、authored shorthand/comment bytesは不変である（Then）
        #expect(flex.resolvedValues["flex-direction"] == "column")
        #expect(flex.resolvedValues["flex-wrap"] == "wrap")
        #expect(flex.resolvedValues["flex-direction"] == browser["flexDirection"])
        #expect(flex.resolvedValues["flex-wrap"] == browser["flexWrap"])
        #expect(flex.winners["flex-direction"]?.authoredProperty == "flex-flow")
        #expect(
            grid.resolvedValues["grid-template-rows"]
                == browser["gridRows"]?.replacingOccurrences(of: "0px", with: "0")
        )
        #expect(grid.resolvedValues["grid-template-columns"] == "[col-start] 1fr 2fr")
        #expect(grid.resolvedValues["grid-template-columns"] == browser["gridColumns"])
        #expect(grid.winners["grid-template-columns"]?.authoredProperty == "grid-template")
        #expect(browser["invalidRows"] == "")
        #expect(invalid.winners["grid-template-rows"] == nil)
        #expect(invalid.winners["grid-template-columns"] == nil)
        #expect(document.source == css)
    }

    /// 論理名（日本語）: Structural/sibling selector WebKit parityテスト
    /// 概要: adjacent/general siblingとfirst/last/nth childをbrowser DOM sibling metadataで照合します。
    @Test("siblingとstructural selectorのsource cascadeはWebKitと一致する")
    func testSiblingAndStructuralSelectorsMatchWebKit() async throws {
        // コンディション：adjacent/general siblingとstructural pseudoを組み合わせたlist CSSを用意する（Given）
        let css = """
        li:first-child + li:nth-child(2) { color: rgb(10, 20, 30); }
        li:first-child ~ li:last-child { background: rgb(40, 50, 60); }
        """
        let html = """
        <!doctype html><html><head><style>\(css)</style></head><body><ul>
          <li id="first">One</li><li id="second">Two</li><li id="last">Three</li>
        </ul></body></html>
        """
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
        let waiter = CSSWebViewNavigationWaiter()
        try await waiter.load(html, in: webView)

        // 検証内容：WebKit computed値とShared browser projection traceを取得する（When）
        let computed = try #require(try await webView.evaluateJavaScript(
            """
            (() => ({
              second: getComputedStyle(document.getElementById('second')).color,
              last: getComputedStyle(document.getElementById('last')).backgroundColor
            }))()
            """
        ) as? [String: String])
        let nodes = OpenGraphiteHTMLDocument(html: html).nodes(
            companionCSS: OpenGraphiteCompanionCSSDocument(css: css),
            documentURL: "file:///structural-selector.html"
        )
        let second = try #require(nodes.first { $0.attributes["id"] == "second" })
        let last = try #require(nodes.first { $0.attributes["id"] == "last" })

        // 期待値：sibling/context selector winnerが両評価面で一致する（Then）
        #expect(second.cssResolvedValues["color"] == computed["second"])
        #expect(last.cssResolvedValues["background"] == computed["last"])
        #expect(second.cssSourceTrace["color"]?.last?.selector.contains("+") == true)
        #expect(last.cssSourceTrace["background"]?.last?.selector.contains("~") == true)
    }

    /// 論理名（日本語）: Until-found content visibility WebKit parityテスト
    /// 概要: `hidden=until-found`のUA fallbackを、author `initial`/`unset`/`visible`が標準cascadeで上書きします。
    @Test("until-found content-visibilityのUA fallbackとCSS-wide値はWebKitと一致する")
    func testUntilFoundContentVisibilityCSSWideValuesMatchWebKit() async throws {
        // コンディション：bare until-foundと3種類のauthor content-visibility値を同じdocumentへ用意する（Given）
        let html = """
        <!doctype html><html><body>
          <section id="bare" hidden="until-found">Bare</section>
          <section id="initial" hidden="until-found" style="content-visibility: initial">Initial</section>
          <section id="unset" hidden="until-found" style="content-visibility: unset">Unset</section>
          <section id="visible" hidden="until-found" style="content-visibility: visible">Visible</section>
        </body></html>
        """
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
        let waiter = CSSWebViewNavigationWaiter()
        try await waiter.load(html, in: webView)

        // 検証内容：WebKit computed valueとShared source graphを取得する（When）
        let identifiers = ["bare", "initial", "unset", "visible"]
        let javascriptIdentifiers = identifiers.map { "'\($0)'" }.joined(separator: ",")
        let computed = try #require(try await webView.evaluateJavaScript(
            "Object.fromEntries([\(javascriptIdentifiers)].map(id => [id, getComputedStyle(document.getElementById(id)).contentVisibility]))"
        ) as? [String: String])
        let nodes = OpenGraphiteHTMLDocument(html: html).nodes(
            documentURL: "file:///until-found-content-visibility.html"
        )

        // 期待値：bareだけUA hiddenとなり、author値はinitial semanticsのvisibleへ解決される（Then）
        for identifier in identifiers {
            let node = try #require(nodes.first { $0.attributes["id"] == identifier })
            #expect(node.hidden == true)
            #expect(node.cssResolvedValues["content-visibility"] == computed[identifier])
            #expect(node.hasIncompleteCSSProvenance == false)
        }
        #expect(computed["bare"] == "hidden")
        #expect(computed["initial"] == "visible")
        #expect(computed["unset"] == "visible")
        #expect(computed["visible"] == "visible")
    }

    /// 論理名（日本語）: HTML UA display state WebKit parityテスト
    /// 概要: dialog/input/details/summary/slot/hidden stateとcontext依存UA display fallbackをWebKitに合わせます。
    @Test("stateとcontext依存UA display fallbackはWebKitと一致する")
    func testStateAwareUADisplayFallbackMatchesWebKit() async throws {
        // コンディション：UA displayがtagだけでは決まらない標準HTML要素を同じdocumentへ用意する（Given）
        let html = """
        <!doctype html><html><body>
          <dialog id="dialog-closed">Closed</dialog><dialog id="dialog-open" open>Open</dialog>
          <input id="input-hidden" type="HIDDEN"><input id="input-text" type="text">
          <details id="details"><summary id="summary-first">First</summary><summary id="summary-second">Second</summary></details>
          <summary id="summary-standalone">Standalone</summary><slot id="slot"></slot>
          <search id="search">Search</search><fieldset><legend id="legend">Legend</legend></fieldset>
          <div id="hidden" hidden>Hidden</div><div id="until" hidden="UNTIL-FOUND">Until</div>
          <embed id="embed-hidden" hidden src="about:blank">
        </body></html>
        """
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
        let waiter = CSSWebViewNavigationWaiter()
        try await waiter.load(html, in: webView)

        // 検証内容：各elementのcomputed displayをWebKitとShared graphから取得する（When）
        let identifiers = [
            "dialog-closed", "dialog-open", "input-hidden", "input-text", "summary-first",
            "summary-second", "summary-standalone", "slot", "search", "legend", "hidden",
            "until", "embed-hidden"
        ]
        let javascriptIdentifiers = identifiers.map { "'\($0)'" }.joined(separator: ",")
        let computed = try #require(try await webView.evaluateJavaScript(
            "Object.fromEntries([\(javascriptIdentifiers)].map(id => [id, getComputedStyle(document.getElementById(id)).display]))"
        ) as? [String: String])
        let nodes = OpenGraphiteHTMLDocument(html: html).nodes(documentURL: "file:///ua-display.html")

        // 期待値：sourceを変更せず、state/contextを含むUA fallbackがbrowser computed displayと一致する（Then）
        for identifier in identifiers {
            let node = try #require(nodes.first { $0.attributes["id"] == identifier })
            #expect(node.cssResolvedValues["display"] == computed[identifier])
        }
        let until = try #require(nodes.first { $0.attributes["id"] == "until" })
        #expect(until.cssResolvedValues["content-visibility"] == "hidden")
    }

}

/// 論理名（日本語）: CSS統合テスト用WebView navigation待機クラス
/// 概要: HTML string のnavigation完了または失敗をasync testへ橋渡しします。
@MainActor
private final class CSSWebViewNavigationWaiter: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    /// 論理名（日本語）: CSS統合HTML読み込み関数
    /// 処理概要: 指定HTMLをWebViewへ読み込み、navigation完了まで待機します。
    ///
    /// - Parameters:
    ///   - html: 読み込むHTML。
    ///   - webView: 読み込み先WebView。
    func load(_ html: String, in webView: WKWebView) async throws {
        webView.navigationDelegate = self
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            continuation?.resume()
            continuation = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
