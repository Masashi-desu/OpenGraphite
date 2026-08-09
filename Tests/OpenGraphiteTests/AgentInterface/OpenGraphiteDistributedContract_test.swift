import Foundation
import Testing
@testable import OpenGraphite

/// 論理名（日本語）: 配布Web契約テストスイート
/// 概要: editor runtime-private state が機械可読contractやstatic build成果物へ混入しないことを検証します。
@Suite("配布Web契約テストスイート")
struct OpenGraphiteDistributedContractTests {
    /// 論理名（日本語）: 標準layout配布契約テスト
    /// 概要: layout/hidden/text wrapの描画契約を標準HTML/CSSへ移し、binding metadataだけを機械可読契約に残します。
    @Test("標準layout配布契約からlegacy描画selectorを除外する")
    func testStandardLayoutContractExcludesLegacyRenderingSelectors() throws {
        // コンディション：repository contract、built-in contract、配布CSSとheadless runtime sourceを取得する（Given）
        let testURL = URL(fileURLWithPath: #filePath)
        let contractURL = try #require(OpenGraphiteContract.findContractURL(startingAt: testURL))
        let repositoryURL = contractURL.deletingLastPathComponent()
        let repositoryContract = try OpenGraphiteContract.load(from: contractURL)
        let distributedCSS = try String(
            contentsOf: repositoryURL.appendingPathComponent("CSS/OpenGraphite.css"),
            encoding: .utf8
        )
        let screenshotRuntime = try String(
            contentsOf: repositoryURL.appendingPathComponent(
                "Shared/Sources/AgentInterface/OpenGraphiteScreenshotRenderer.swift"
            ),
            encoding: .utf8
        )

        // 検証内容：editable contractと配布sourceのlegacy描画tokenを検査する（When）
        let standardProperties = [
            "display", "flex-direction",
            "grid-template-columns", "grid-template-rows",
            "grid-auto-columns", "grid-auto-rows", "grid-auto-flow",
            "grid-column", "grid-row", "position", "visibility", "overflow-wrap"
        ]

        // 期待値：JSON/built-inは一致し、標準属性/propertyだけが編集可能でhiddenの描画はUAへ委譲する（Then）
        #expect(repositoryContract == .builtIn)
        #expect(repositoryContract.layouts.isEmpty)
        #expect(repositoryContract.editableAttributeSet.contains("hidden"))
        #expect(repositoryContract.editableAttributeSet.contains("data-og-text-source"))
        #expect(!repositoryContract.editableAttributeSet.contains("data-og-layout"))
        #expect(!repositoryContract.editableAttributeSet.contains("data-og-hidden"))
        for property in standardProperties {
            #expect(repositoryContract.cssVariables.contains { $0.name == property && $0.editable })
        }
        for token in ["data-og-layout", "data-og-hidden", "data-og-text-source"] {
            #expect(!distributedCSS.contains(token))
        }
        #expect(!distributedCSS.contains(":where([hidden]"))
        #expect(!distributedCSS.contains("data-og-type"))
        #expect(!screenshotRuntime.contains("data-og-hidden"))
    }

    /// 論理名（日本語）: Runtime helper配布禁止テスト
    /// 概要: Web contract 1.0.0で廃止したruntime・theme・locale・media/icon・scale・placement state helperが配布sourceとbuild出力に現れないことを確認します。
    @Test("廃止済みhelperをcontractとstatic buildへ配布しない")
    func testRuntimePrivateHelpersAreAbsentFromDistributedArtifacts() throws {
        // コンディション：repository・built-in contract、配布CSS・public・browser/static source、標準sample projectがある（Given）
        let testURL = URL(fileURLWithPath: #filePath)
        let contractURL = try #require(OpenGraphiteContract.findContractURL(startingAt: testURL))
        let repositoryURL = contractURL.deletingLastPathComponent()
        let repositoryContract = try OpenGraphiteContract.load(from: contractURL)
        let distributedSourceURLs = [
            contractURL,
            repositoryURL.appendingPathComponent("CSS/OpenGraphite.css"),
            repositoryURL.appendingPathComponent("public/OpenGraphite.runtime.js"),
            repositoryURL.appendingPathComponent("App/Sources/Editor/WebCanvasView.swift"),
            repositoryURL.appendingPathComponent("Shared/Sources/AgentInterface/OpenGraphiteScreenshotRenderer.swift")
        ]
        let legacyPlacementStateAttributes = [
            "data-og-placement-mode",
            "data-og-state-hidden",
            "data-og-state-visible"
        ]
        let forbidden = [
            "--og-preview-locale",
            "--og-preview-dir",
            "--og-edit-width",
            "--og-edit-min-height",
            "--og-drag-x",
            "--og-drag-y",
            "--og-reorder-x",
            "--og-reorder-y",
            "--og-page-background",
            "--og-text-color",
            "--og-muted-color",
            "--og-accent",
            "--og-accent-foreground",
            "--og-font-family-default",
            "--og-font-family-ja",
            "--og-font-family-en",
            "--og-font-family-eng",
            "--og-active-font-family",
            "--og-object-fit",
            "--og-stroke-width",
            "--og-icon-url",
            "--og-scale-x",
            "--og-scale-y",
            "data-og-selected",
            "data-og-editing",
            "data-og-editor-focus-root",
            "data-og-editor-focus-visible",
            "data-og-dragging",
            "data-og-reorder-dragging",
            "data-og-reorder-animating",
            "data-og-reorder-preparing",
            "data-og-frame-preview",
            "data-og-editor-artifact",
            "data-og-expanded",
            "data-og-generated",
            "data-og-component-error",
            "data-og-host-id",
            "data-og-instance-source",
            "data-og-source-id",
            "data-og-source-instance",
            "data-og-slot-origin",
            "data-og-preview-clone",
            "data-og-preview-locale",
            "data-og-preview-dir",
            "data-og-icon-mask",
            "data-og-placement-generated",
            "data-og-placement-mode",
            "data-og-source-placement",
            "data-og-state-hidden",
            "data-og-state-visible",
            "data-og-runtime-fallback-html"
        ]
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenGraphite-WSCM012-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: outputURL) }

        // 検証内容：sampleをstatic buildし、public sourceとbuild出力のtext資源を再帰収集する（When）
        _ = try OpenGraphiteComponentBuilder().buildProject(
            projectURL: repositoryURL.appendingPathComponent("SampleProject/OpenGraphiteSample.ogp"),
            outputURL: outputURL
        )
        let publicTextURLs = try textArtifactURLs(in: repositoryURL.appendingPathComponent("public"))
        let builtTextURLs = try textArtifactURLs(in: outputURL)
        let inspectedURLs = distributedSourceURLs + publicTextURLs + builtTextURLs

        // 期待値：JSONとbuilt-inは一致し、旧3属性を含むruntime-private helperは全配布sourceとbuild成果物に存在しない（Then）
        #expect(repositoryContract == .builtIn)
        for attribute in legacyPlacementStateAttributes {
            #expect(!OpenGraphiteContract.builtIn.editableAttributeSet.contains(attribute))
        }
        for url in inspectedURLs {
            let source = try String(contentsOf: url, encoding: .utf8)
            for token in forbidden {
                #expect(!source.contains(token), "\(url.path) にruntime-private helper \(token) が残っています")
            }
        }
    }

    /// 論理名（日本語）: Build text成果物URL収集関数
    /// 処理概要: publicまたはstatic buildディレクトリを再帰走査し、配布対象のHTML・CSS・JavaScript・JSONだけを返します。
    ///
    /// - Parameter rootURL: static build出力ディレクトリ。
    /// - Returns: path順に整列したtext成果物URL。
    private func textArtifactURLs(in rootURL: URL) throws -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey]
        let enumerator = try #require(
            FileManager.default.enumerator(
                at: rootURL,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            )
        )
        let extensions = Set(["html", "css", "js", "json"])
        var urls: [URL] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            if values.isRegularFile == true, extensions.contains(url.pathExtension.lowercased()) {
                urls.append(url)
            }
        }
        return urls.sorted { $0.path < $1.path }
    }
}
