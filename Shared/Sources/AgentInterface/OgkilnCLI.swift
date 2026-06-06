import Foundation

/// 論理名（日本語）: ogkiln CLI
/// 概要: OpenGraphite repository を inspection、validation、node 単位編集するコマンドライン実装です。
///
/// メソッド:
/// - `run(arguments:currentDirectory:stdout:stderr:)`: CLI 引数を解釈してコマンドを実行します。
struct OgkilnCLI {
    /// 論理名（日本語）: CLI実行関数
    /// 処理概要: `ogkiln` の引数を解析し、project / page / validate / node コマンドを実行します。
    ///
    /// - Parameters:
    ///   - arguments: `CommandLine.arguments.dropFirst()` 相当の引数。
    ///   - currentDirectory: 相対パス解決の基準ディレクトリ。
    ///   - stdout: 標準出力へ書き込むクロージャ。
    ///   - stderr: 標準エラーへ書き込むクロージャ。
    /// - Returns: プロセス終了コード。
    func run(
        arguments: [String],
        currentDirectory: URL,
        stdout: (String) -> Void,
        stderr: (String) -> Void
    ) -> Int32 {
        do {
            guard !arguments.isEmpty, !arguments.contains("--help") else {
                stdout(Self.helpText)
                return 0
            }

            let contract = OpenGraphiteContract.loadDefault(startingAt: currentDirectory)
            let core = OpenGraphiteAgentCore(contract: contract)
            let output = try execute(arguments: arguments, currentDirectory: currentDirectory, core: core)
            stdout(output.json)
            return output.exitCode
        } catch let error as OgkilnCLIError {
            stderr(error.message)
            return error.exitCode
        } catch {
            stderr(error.localizedDescription)
            return 1
        }
    }

    private func execute(
        arguments: [String],
        currentDirectory: URL,
        core: OpenGraphiteAgentCore
    ) throws -> OgkilnOutput {
        switch arguments.prefix(2) {
        case ["contract", "get"]:
            return try OgkilnOutput(object: core.contract, exitCode: 0)

        case ["project", "current"]:
            let projectURL = try OpenGraphiteCurrentProjectStore().readProjectURL()
            let summary = try core.inspectProject(at: projectURL)
            return try OgkilnOutput(object: summary, exitCode: summary.diagnostics.contains { $0.severity == .error } ? 1 : 0)

        case ["project", "inspect"]:
            let projectURL = try projectURL(from: positional(arguments, at: 2, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let summary = try core.inspectProject(at: projectURL)
            return try OgkilnOutput(object: summary, exitCode: summary.diagnostics.contains { $0.severity == .error } ? 1 : 0)

        case ["project", "page"]:
            guard arguments.indices.contains(2) else { break }
            switch arguments[2] {
            case "add":
                let projectURL = try projectURL(from: positional(arguments, at: 3, description: ".ogp path or current"), currentDirectory: currentDirectory)
                let id = try requiredOption("--page-id", in: arguments)
                let pagePath = try requiredOption("--path", in: arguments)
                let canvas = OpenGraphiteCanvas(
                    x: try doubleOption("--x", in: arguments) ?? 0,
                    y: try doubleOption("--y", in: arguments) ?? 0,
                    width: try doubleOption("--width", in: arguments) ?? 1440,
                    height: try doubleOption("--height", in: arguments) ?? 1200
                )
                let summary = try core.addProjectPage(
                    projectURL: projectURL,
                    id: id,
                    path: pagePath,
                    canvas: canvas,
                    allowDuplicatePath: hasFlag("--allow-duplicate-path", in: arguments)
                )
                return try OgkilnOutput(object: summary, exitCode: summary.diagnostics.contains { $0.severity == .error } ? 1 : 0)
            case "create":
                let projectURL = try projectURL(from: positional(arguments, at: 3, description: ".ogp path or current"), currentDirectory: currentDirectory)
                let id = try requiredOption("--page-id", in: arguments)
                let pagePath = try requiredOption("--path", in: arguments)
                let title = try optionalOption("--title", in: arguments) ?? id
                let lang = try optionalOption("--lang", in: arguments) ?? "ja"
                let canvas = OpenGraphiteCanvas(
                    x: try doubleOption("--x", in: arguments) ?? 0,
                    y: try doubleOption("--y", in: arguments) ?? 0,
                    width: try doubleOption("--width", in: arguments) ?? 1440,
                    height: try doubleOption("--height", in: arguments) ?? 1200
                )
                let body = try optionalOption("--body-html", in: arguments)
                    ?? htmlFromFile(requiredOption("--body-file", in: arguments), currentDirectory: currentDirectory)
                let result = try core.createProjectPage(
                    projectURL: projectURL,
                    id: id,
                    path: pagePath,
                    canvas: canvas,
                    title: title,
                    lang: lang,
                    stylesheetPath: try optionalOption("--stylesheet", in: arguments),
                    bodyHTML: body,
                    overwrite: hasFlag("--overwrite", in: arguments)
                )
                return try OgkilnOutput(object: result, exitCode: result.created ? 0 : 1)
            case "place":
                let projectURL = try projectURL(from: positional(arguments, at: 3, description: ".ogp path or current"), currentDirectory: currentDirectory)
                let id = try requiredOption("--page-id", in: arguments)
                let summary = try core.placeProjectPage(
                    projectURL: projectURL,
                    id: id,
                    name: try optionalOption("--name", in: arguments),
                    x: try doubleOption("--x", in: arguments),
                    y: try doubleOption("--y", in: arguments),
                    width: try doubleOption("--width", in: arguments),
                    height: try doubleOption("--height", in: arguments),
                    previewFieldMocks: try previewFieldMocks(in: arguments)
                )
                return try OgkilnOutput(object: summary, exitCode: summary.diagnostics.contains { $0.severity == .error } ? 1 : 0)
            case "document":
                let projectURL = try projectURL(from: positional(arguments, at: 3, description: ".ogp path or current"), currentDirectory: currentDirectory)
                let id = try requiredOption("--page-id", in: arguments)
                let currentContext = try currentHTMLDocumentContext(projectURL: projectURL, pageID: id, core: core)
                let result = try core.setProjectPageHTMLDocumentContext(
                    projectURL: projectURL,
                    id: id,
                    context: try htmlDocumentContext(in: arguments, current: currentContext)
                )
                return try OgkilnOutput(object: result, exitCode: result.diagnostics.contains { $0.severity == .error } ? 1 : 0)
            default:
                break
            }

        case ["project", "component"]:
            guard arguments.indices.contains(2) else { break }
            switch arguments[2] {
            case "add":
                let projectURL = try projectURL(from: positional(arguments, at: 3, description: ".ogp path or current"), currentDirectory: currentDirectory)
                let id = try requiredComponentID(in: arguments)
                let pagePath = try requiredOption("--path", in: arguments)
                let canvas = OpenGraphiteCanvas(
                    x: try doubleOption("--x", in: arguments) ?? 0,
                    y: try doubleOption("--y", in: arguments) ?? 0,
                    width: try doubleOption("--width", in: arguments) ?? 960,
                    height: try doubleOption("--height", in: arguments) ?? 900
                )
                let summary = try core.addProjectComponent(
                    projectURL: projectURL,
                    collectionID: try optionalOption("--collection-id", in: arguments),
                    id: id,
                    path: pagePath,
                    canvas: canvas
                )
                return try OgkilnOutput(object: summary, exitCode: summary.diagnostics.contains { $0.severity == .error } ? 1 : 0)
            case "create":
                let projectURL = try projectURL(from: positional(arguments, at: 3, description: ".ogp path or current"), currentDirectory: currentDirectory)
                let id = try requiredComponentID(in: arguments)
                let pagePath = try requiredOption("--path", in: arguments)
                let title = try optionalOption("--title", in: arguments) ?? id
                let lang = try optionalOption("--lang", in: arguments) ?? "ja"
                let canvas = OpenGraphiteCanvas(
                    x: try doubleOption("--x", in: arguments) ?? 0,
                    y: try doubleOption("--y", in: arguments) ?? 0,
                    width: try doubleOption("--width", in: arguments) ?? 960,
                    height: try doubleOption("--height", in: arguments) ?? 900
                )
                let body = try optionalOption("--body-html", in: arguments)
                    ?? htmlFromFile(requiredOption("--body-file", in: arguments), currentDirectory: currentDirectory)
                let result = try core.createProjectComponent(
                    projectURL: projectURL,
                    collectionID: try optionalOption("--collection-id", in: arguments),
                    id: id,
                    path: pagePath,
                    canvas: canvas,
                    title: title,
                    lang: lang,
                    stylesheetPath: try optionalOption("--stylesheet", in: arguments),
                    bodyHTML: body,
                    overwrite: hasFlag("--overwrite", in: arguments)
                )
                return try OgkilnOutput(object: result, exitCode: result.created ? 0 : 1)
            case "place":
                let projectURL = try projectURL(from: positional(arguments, at: 3, description: ".ogp path or current"), currentDirectory: currentDirectory)
                let id = try requiredComponentID(in: arguments)
                let summary = try core.placeProjectComponent(
                    projectURL: projectURL,
                    id: id,
                    name: try optionalOption("--name", in: arguments),
                    x: try doubleOption("--x", in: arguments),
                    y: try doubleOption("--y", in: arguments),
                    width: try doubleOption("--width", in: arguments),
                    height: try doubleOption("--height", in: arguments),
                    previewFieldMocks: try previewFieldMocks(in: arguments)
                )
                return try OgkilnOutput(object: summary, exitCode: summary.diagnostics.contains { $0.severity == .error } ? 1 : 0)
            case "document":
                let projectURL = try projectURL(from: positional(arguments, at: 3, description: ".ogp path or current"), currentDirectory: currentDirectory)
                let id = try requiredComponentID(in: arguments)
                let currentContext = try currentHTMLDocumentContext(projectURL: projectURL, pageID: id, core: core)
                let result = try core.setProjectComponentHTMLDocumentContext(
                    projectURL: projectURL,
                    id: id,
                    context: try htmlDocumentContext(in: arguments, current: currentContext)
                )
                return try OgkilnOutput(object: result, exitCode: result.diagnostics.contains { $0.severity == .error } ? 1 : 0)
            case "remove":
                let projectURL = try projectURL(from: positional(arguments, at: 3, description: ".ogp path or current"), currentDirectory: currentDirectory)
                let id = try requiredComponentID(in: arguments)
                let summary = try core.removeProjectComponent(
                    projectURL: projectURL,
                    id: id,
                    deleteFile: hasFlag("--delete-file", in: arguments)
                )
                return try OgkilnOutput(object: summary, exitCode: summary.diagnostics.contains { $0.severity == .error } ? 1 : 0)
            default:
                break
            }

        case ["page", "graph"]:
            let projectURL = try projectURL(from: positional(arguments, at: 2, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let graph = try core.pageGraph(projectURL: projectURL, pageID: requiredPageID(in: arguments))
            return try OgkilnOutput(object: graph, exitCode: graph.diagnostics.contains { $0.severity == .error } ? 1 : 0)

        case ["i18n", "inspect"]:
            let projectURL = try projectURL(from: positional(arguments, at: 2, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let result = try core.inspectI18n(
                projectURL: projectURL,
                pageID: requiredPageID(in: arguments),
                locales: try localesOption(in: arguments) ?? ["ja", "eng"]
            )
            return try OgkilnOutput(object: result, exitCode: result.diagnostics.contains { $0.severity == .error } ? 1 : 0)

        case ["i18n", "recommend"]:
            let projectURL = try projectURL(from: positional(arguments, at: 2, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let result = try core.recommendI18n(
                projectURL: projectURL,
                pageID: requiredPageID(in: arguments),
                locales: try localesOption(in: arguments) ?? ["ja", "eng"]
            )
            return try OgkilnOutput(object: result, exitCode: result.diagnostics.contains { $0.severity == .error } ? 1 : 0)

        default:
            break
        }

        if arguments.first == "validate" {
            let targetURL = try projectURL(from: positional(arguments, at: 1, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let result = try core.validateProject(at: targetURL)
            return try OgkilnOutput(object: result, exitCode: result.valid ? 0 : 1)
        }

        if arguments.first == "build" {
            let projectURL = try projectURL(from: positional(arguments, at: 1, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let output = try requiredOption("--output", in: arguments)
            let result = try OpenGraphiteComponentBuilder().buildProject(
                projectURL: projectURL,
                outputURL: url(for: output, currentDirectory: currentDirectory)
            )
            return try OgkilnOutput(object: result, exitCode: result.built ? 0 : 1)
        }

        if arguments.count >= 2, arguments[0] == "screenshot", arguments[1] == "canvas" {
            let projectURL = try projectURL(from: positional(arguments, at: 2, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let output = try requiredOption("--output", in: arguments)
            let result = try OpenGraphiteScreenshotRenderer().captureCanvas(
                projectURL: projectURL,
                outputURL: url(for: output, currentDirectory: currentDirectory)
            )
            return try OgkilnOutput(object: result, exitCode: 0)
        }

        if arguments.count >= 2, arguments[0] == "screenshot", arguments[1] == "page" {
            let projectURL = try projectURL(from: positional(arguments, at: 2, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let output = try requiredOption("--output", in: arguments)
            let result = try OpenGraphiteScreenshotRenderer().capturePage(
                targetURL: projectURL,
                pageID: requiredPageID(in: arguments),
                outputURL: url(for: output, currentDirectory: currentDirectory),
                readAccessURL: currentDirectory,
                width: try doubleOption("--width", in: arguments),
                height: try doubleOption("--height", in: arguments),
                fullPage: hasFlag("--full-page", in: arguments)
            )
            return try OgkilnOutput(object: result, exitCode: 0)
        }

        if arguments.count >= 2, arguments[0] == "screenshot", arguments[1] == "node" {
            let projectURL = try projectURL(from: positional(arguments, at: 2, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let reference = try core.projectPageReference(projectURL: projectURL, pageID: requiredPageID(in: arguments))
            let id = try requiredOption("--id", in: arguments)
            let output = try requiredOption("--output", in: arguments)
            let result = try OpenGraphiteScreenshotRenderer().captureNode(
                htmlURL: URL(fileURLWithPath: reference.htmlURL),
                nodeID: id,
                outputURL: url(for: output, currentDirectory: currentDirectory),
                readAccessURL: URL(fileURLWithPath: reference.rootURL),
                width: try doubleOption("--width", in: arguments) ?? reference.canvas.width,
                height: try doubleOption("--height", in: arguments) ?? reference.canvas.height,
                padding: try doubleOption("--padding", in: arguments),
                previewContext: reference.canvas.previewContext
            )
            return try OgkilnOutput(object: result, exitCode: 0)
        }

        if arguments.count >= 2, arguments[0] == "node", arguments[1] == "query" {
            let projectURL = try projectURL(from: positional(arguments, at: 2, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let query = OpenGraphiteNodeQuery(
                idContains: try optionalOption("--id-contains", in: arguments),
                type: try optionalOption("--type", in: arguments),
                role: try optionalOption("--role", in: arguments),
                tag: try optionalOption("--tag", in: arguments),
                textContains: try optionalOption("--text-contains", in: arguments)
            )
            let result = try core.queryNodes(projectURL: projectURL, pageID: requiredPageID(in: arguments), query: query)
            return try OgkilnOutput(object: result, exitCode: result.diagnostics.contains { $0.severity == .error } ? 1 : 0)
        }

        if arguments.count >= 2, arguments[0] == "node", arguments[1] == "get" {
            let projectURL = try projectURL(from: positional(arguments, at: 2, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let id = try requiredOption("--id", in: arguments)
            let result = try core.node(id: id, projectURL: projectURL, pageID: requiredPageID(in: arguments))
            return try OgkilnOutput(object: result, exitCode: result.diagnostics.contains { $0.severity == .error } ? 1 : 0)
        }

        if arguments.count >= 3, arguments[0] == "node", arguments[1] == "style", arguments[2] == "set" {
            let projectURL = try projectURL(from: positional(arguments, at: 3, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let id = try requiredOption("--id", in: arguments)
            let variable = try requiredOption("--var", in: arguments)
            let value = try requiredOption("--value", in: arguments)
            let result = try core.setCSSVariable(
                variable,
                value: value,
                nodeID: id,
                projectURL: projectURL,
                pageID: requiredPageID(in: arguments)
            )
            return try OgkilnOutput(object: result, exitCode: result.diagnostics.contains { $0.severity == .error } ? 1 : 0)
        }

        if arguments.count >= 3, arguments[0] == "node", arguments[1] == "style", arguments[2] == "remove" {
            let projectURL = try projectURL(from: positional(arguments, at: 3, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let id = try requiredOption("--id", in: arguments)
            let variable = try requiredOption("--var", in: arguments)
            let result = try core.setCSSVariable(
                variable,
                value: "",
                nodeID: id,
                projectURL: projectURL,
                pageID: requiredPageID(in: arguments)
            )
            return try OgkilnOutput(object: result, exitCode: result.diagnostics.contains { $0.severity == .error } ? 1 : 0)
        }

        if arguments.count >= 3, arguments[0] == "node", arguments[1] == "attr", arguments[2] == "set" {
            let projectURL = try projectURL(from: positional(arguments, at: 3, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let id = try requiredOption("--id", in: arguments)
            let name = try requiredOption("--name", in: arguments)
            let value = try requiredOption("--value", in: arguments)
            let result = try core.setAttribute(
                name,
                value: value,
                nodeID: id,
                projectURL: projectURL,
                pageID: requiredPageID(in: arguments)
            )
            return try OgkilnOutput(object: result, exitCode: result.diagnostics.contains { $0.severity == .error } ? 1 : 0)
        }

        if arguments.count >= 3, arguments[0] == "node", arguments[1] == "attr", arguments[2] == "remove" {
            let projectURL = try projectURL(from: positional(arguments, at: 3, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let id = try requiredOption("--id", in: arguments)
            let name = try requiredOption("--name", in: arguments)
            let result = try core.setAttribute(
                name,
                value: "",
                nodeID: id,
                projectURL: projectURL,
                pageID: requiredPageID(in: arguments)
            )
            return try OgkilnOutput(object: result, exitCode: result.diagnostics.contains { $0.severity == .error } ? 1 : 0)
        }

        if arguments.count >= 3, arguments[0] == "node", arguments[1] == "text", arguments[2] == "set" {
            let projectURL = try projectURL(from: positional(arguments, at: 3, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let id = try requiredOption("--id", in: arguments)
            let text = try optionalOption("--value", in: arguments) ?? textFromFile(requiredOption("--text-file", in: arguments), currentDirectory: currentDirectory)
            let result = try core.setTextContent(
                text,
                nodeID: id,
                projectURL: projectURL,
                pageID: requiredPageID(in: arguments)
            )
            return try OgkilnOutput(object: result, exitCode: result.diagnostics.contains { $0.severity == .error } ? 1 : 0)
        }

        if arguments.count >= 3, arguments[0] == "text", arguments[1] == "variant", arguments[2] == "set" {
            let projectURL = try projectURL(from: positional(arguments, at: 3, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let key = try requiredOption("--key", in: arguments)
            let locale = try requiredOption("--locale", in: arguments)
            let text = try optionalOption("--value", in: arguments) ?? textFromFile(requiredOption("--text-file", in: arguments), currentDirectory: currentDirectory)
            let result = try core.setTextVariant(
                text,
                locale: locale,
                i18nKey: key,
                projectURL: projectURL,
                pageID: requiredPageID(in: arguments)
            )
            return try OgkilnOutput(object: result, exitCode: result.diagnostics.contains { $0.severity == .error } ? 1 : 0)
        }

        if arguments.count >= 3, arguments[0] == "i18n", arguments[1] == "resource", arguments[2] == "set" {
            let projectURL = try projectURL(from: positional(arguments, at: 3, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let key = try requiredOption("--key", in: arguments)
            let locale = try requiredOption("--locale", in: arguments)
            let text = try optionalOption("--value", in: arguments) ?? textFromFile(requiredOption("--text-file", in: arguments), currentDirectory: currentDirectory)
            let result = try core.setI18nResourceValue(
                text,
                locale: locale,
                key: key,
                projectURL: projectURL,
                pageID: requiredPageID(in: arguments)
            )
            return try OgkilnOutput(object: result, exitCode: result.diagnostics.contains { $0.severity == .error } ? 1 : 0)
        }

        if arguments.count >= 3, arguments[0] == "node", arguments[1] == "html", arguments[2] == "insert" {
            let projectURL = try projectURL(from: positional(arguments, at: 3, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let id = try requiredOption("--id", in: arguments)
            let position = try insertionPosition(from: requiredOption("--position", in: arguments))
            let html = try htmlOption(arguments, currentDirectory: currentDirectory)
            let result = try core.insertHTML(
                html,
                anchorNodeID: id,
                position: position,
                projectURL: projectURL,
                pageID: requiredPageID(in: arguments)
            )
            return try OgkilnOutput(object: result, exitCode: result.diagnostics.contains { $0.severity == .error } ? 1 : 0)
        }

        if arguments.count >= 3, arguments[0] == "node", arguments[1] == "html", arguments[2] == "replace" {
            let projectURL = try projectURL(from: positional(arguments, at: 3, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let id = try requiredOption("--id", in: arguments)
            let html = try htmlOption(arguments, currentDirectory: currentDirectory)
            let result = try core.replaceNodeHTML(
                html,
                nodeID: id,
                projectURL: projectURL,
                pageID: requiredPageID(in: arguments)
            )
            return try OgkilnOutput(object: result, exitCode: result.diagnostics.contains { $0.severity == .error } ? 1 : 0)
        }

        if arguments.count >= 2, arguments[0] == "node", arguments[1] == "delete" {
            let projectURL = try projectURL(from: positional(arguments, at: 2, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let id = try requiredOption("--id", in: arguments)
            let result = try core.deleteNode(
                nodeID: id,
                projectURL: projectURL,
                pageID: requiredPageID(in: arguments)
            )
            return try OgkilnOutput(object: result, exitCode: result.diagnostics.contains { $0.severity == .error } ? 1 : 0)
        }

        if arguments.count >= 2, arguments[0] == "node", arguments[1] == "move" {
            let projectURL = try projectURL(from: positional(arguments, at: 2, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let id = try requiredOption("--id", in: arguments)
            let target = try requiredOption("--target", in: arguments)
            let position = try insertionPosition(from: requiredOption("--position", in: arguments))
            let result = try core.moveNode(
                nodeID: id,
                targetNodeID: target,
                position: position,
                projectURL: projectURL,
                pageID: requiredPageID(in: arguments)
            )
            return try OgkilnOutput(object: result, exitCode: result.diagnostics.contains { $0.severity == .error } ? 1 : 0)
        }

        if arguments.count >= 2, arguments[0] == "node", arguments[1] == "copy" {
            let projectURL = try projectURL(from: positional(arguments, at: 2, description: ".ogp path or current"), currentDirectory: currentDirectory)
            let id = try requiredOption("--id", in: arguments)
            let target = try requiredOption("--target", in: arguments)
            let position = try insertionPosition(from: requiredOption("--position", in: arguments))
            let idPrefix = try requiredOption("--id-prefix", in: arguments)
            let result = try core.copyNode(
                nodeID: id,
                targetNodeID: target,
                position: position,
                idPrefix: idPrefix,
                projectURL: projectURL,
                pageID: requiredPageID(in: arguments)
            )
            return try OgkilnOutput(object: result, exitCode: result.diagnostics.contains { $0.severity == .error } ? 1 : 0)
        }

        throw OgkilnCLIError(message: "未知のコマンドです。\n\n\(Self.helpText)", exitCode: 2)
    }

    private func positional(_ arguments: [String], at index: Int, description: String) throws -> String {
        guard arguments.indices.contains(index), !arguments[index].hasPrefix("--") else {
            throw OgkilnCLIError(message: "\(description) が指定されていません。", exitCode: 2)
        }
        return arguments[index]
    }

    private func requiredOption(_ name: String, in arguments: [String]) throws -> String {
        guard let index = arguments.firstIndex(of: name),
              arguments.indices.contains(arguments.index(after: index)) else {
            throw OgkilnCLIError(message: "\(name) が指定されていません。", exitCode: 2)
        }
        return arguments[arguments.index(after: index)]
    }

    private func optionalOption(_ name: String, in arguments: [String]) throws -> String? {
        guard let index = arguments.firstIndex(of: name) else {
            return nil
        }
        guard arguments.indices.contains(arguments.index(after: index)) else {
            throw OgkilnCLIError(message: "\(name) の値が指定されていません。", exitCode: 2)
        }
        return arguments[arguments.index(after: index)]
    }

    /// 論理名（日本語）: 複数オプション値取得関数
    /// 処理概要: 同じ option name が複数回指定された場合の値を出現順に返します。
    ///
    /// - Parameters:
    ///   - name: 取得する option name。
    ///   - arguments: CLI 引数。
    /// - Returns: option に指定された値一覧。
    private func optionValues(_ name: String, in arguments: [String]) throws -> [String] {
        var values: [String] = []
        var index = arguments.startIndex
        while index < arguments.endIndex {
            defer { index = arguments.index(after: index) }
            guard arguments[index] == name else { continue }
            let valueIndex = arguments.index(after: index)
            guard arguments.indices.contains(valueIndex) else {
                throw OgkilnCLIError(message: "\(name) の値が指定されていません。", exitCode: 2)
            }
            values.append(arguments[valueIndex])
        }
        return values
    }

    /// 論理名（日本語）: 現在HTML Document Context取得関数
    /// 処理概要: `.ogp` の page / component 参照から HTML 正本を読み、現在の document context を返します。
    ///
    /// - Parameters:
    ///   - projectURL: `.ogp` ファイル URL。
    ///   - pageID: `.ogp` 内 page / component 参照 ID。
    ///   - core: HTML 参照解決に使う agent core。
    /// - Returns: 現在の HTML document context。
    private func currentHTMLDocumentContext(
        projectURL: URL,
        pageID: String,
        core: OpenGraphiteAgentCore
    ) throws -> OpenGraphiteHTMLDocumentContext {
        let reference = try core.projectPageReference(projectURL: projectURL, pageID: pageID)
        let html = try String(contentsOf: URL(fileURLWithPath: reference.htmlURL), encoding: .utf8)
        return OpenGraphiteHTMLDocument(html: html).htmlDocumentContext()
    }

    /// 論理名（日本語）: HTML Document Context入力取得関数
    /// 処理概要: CLI option の指定分だけ現在値へ上書きし、保存用 context を作ります。
    ///
    /// - Parameters:
    ///   - arguments: CLI 引数。
    ///   - current: 現在の HTML document context。
    /// - Returns: 更新後 context。
    private func htmlDocumentContext(
        in arguments: [String],
        current: OpenGraphiteHTMLDocumentContext
    ) throws -> OpenGraphiteHTMLDocumentContext {
        OpenGraphiteHTMLDocumentContext(
            langSource: try htmlLangSourceOption("--lang-source", in: arguments) ?? current.langSource,
            langValue: try optionalOption("--lang", in: arguments) ?? current.langValue,
            langField: try optionalOption("--lang-field", in: arguments) ?? current.langField,
            dirSource: try htmlDirSourceOption("--dir-source", in: arguments) ?? current.dirSource,
            dirValue: try optionalOption("--dir", in: arguments) ?? current.dirValue,
            dirField: try optionalOption("--dir-field", in: arguments) ?? current.dirField
        )
    }

    /// 論理名（日本語）: HTML Lang source option取得関数
    /// 処理概要: `--lang-source` を `literal` / `binding` として検証します。
    ///
    /// - Parameters:
    ///   - name: option 名。
    ///   - arguments: CLI 引数。
    /// - Returns: 指定がある場合は source mode。
    private func htmlLangSourceOption(_ name: String, in arguments: [String]) throws -> OpenGraphiteHTMLLangSource? {
        guard let value = try optionalOption(name, in: arguments) else {
            return nil
        }
        guard let source = OpenGraphiteHTMLLangSource(rawValue: value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw OgkilnCLIError(message: "\(name) は literal / binding のいずれかを指定してください。", exitCode: 2)
        }
        return source
    }

    /// 論理名（日本語）: HTML Dir source option取得関数
    /// 処理概要: `--dir-source` を `literal` / `auto` / `binding` として検証します。
    ///
    /// - Parameters:
    ///   - name: option 名。
    ///   - arguments: CLI 引数。
    /// - Returns: 指定がある場合は source mode。
    private func htmlDirSourceOption(_ name: String, in arguments: [String]) throws -> OpenGraphiteHTMLDirSource? {
        guard let value = try optionalOption(name, in: arguments) else {
            return nil
        }
        guard let source = OpenGraphiteHTMLDirSource(rawValue: value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw OgkilnCLIError(message: "\(name) は literal / auto / binding のいずれかを指定してください。", exitCode: 2)
        }
        return source
    }

    /// 論理名（日本語）: Preview runtime mock state取得関数
    /// 処理概要: `--preview-mock key=value` の繰り返し指定を辞書へ変換します。
    ///
    /// - Parameter arguments: CLI 引数。
    /// - Returns: 指定がない場合は `nil`、ある場合は mock field 辞書。
    private func previewFieldMocks(in arguments: [String]) throws -> [String: String]? {
        let values = try optionValues("--preview-mock", in: arguments)
        guard !values.isEmpty else { return nil }
        var result: [String: String] = [:]
        for value in values {
            guard let separatorIndex = value.firstIndex(of: "=") else {
                throw OgkilnCLIError(message: "--preview-mock は key=value で指定してください。", exitCode: 2)
            }
            let key = value[..<separatorIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let fieldValue = value[value.index(after: separatorIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else {
                throw OgkilnCLIError(message: "--preview-mock の key は空にできません。", exitCode: 2)
            }
            result[key] = fieldValue
        }
        return result
    }

    /// 論理名（日本語）: locale一覧option取得関数
    /// 処理概要: `--locales ja,eng` を重複なしの locale 配列へ変換します。
    ///
    /// - Parameter arguments: CLI 引数。
    /// - Returns: 指定がない場合は `nil`。
    private func localesOption(in arguments: [String]) throws -> [String]? {
        guard let value = try optionalOption("--locales", in: arguments) else {
            return nil
        }
        var locales: [String] = []
        for item in value.split(separator: ",", omittingEmptySubsequences: false) {
            let locale = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !locale.isEmpty, !locales.contains(locale) else { continue }
            locales.append(locale)
        }
        guard !locales.isEmpty else {
            throw OgkilnCLIError(message: "--locales は ja,eng のように空でない locale を指定してください。", exitCode: 2)
        }
        return locales
    }

    private func hasFlag(_ name: String, in arguments: [String]) -> Bool {
        arguments.contains(name)
    }

    private func doubleOption(_ name: String, in arguments: [String]) throws -> Double? {
        guard let value = try optionalOption(name, in: arguments) else {
            return nil
        }
        guard let number = Double(value) else {
            throw OgkilnCLIError(message: "\(name) は数値で指定してください。", exitCode: 2)
        }
        return number
    }

    private func url(for path: String, currentDirectory: URL) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardizedFileURL
        }
        return currentDirectory.appendingPathComponent(path).standardizedFileURL
    }

    /// 論理名（日本語）: プロジェクトURL解決関数
    /// 処理概要: `current` または `.ogp` path から編集対象 project URL を解決します。
    ///
    /// - Parameters:
    ///   - value: `current` または `.ogp` path。
    ///   - currentDirectory: 相対パス解決の基準ディレクトリ。
    /// - Returns: 解決済み `.ogp` URL。
    private func projectURL(from value: String, currentDirectory: URL) throws -> URL {
        if value == "current" {
            return try OpenGraphiteCurrentProjectStore().readProjectURL()
        }

        let resolvedURL = url(for: value, currentDirectory: currentDirectory)
        guard resolvedURL.pathExtension == "ogp" else {
            throw OgkilnCLIError(message: "編集対象は .ogp path または current で指定してください: \(value)", exitCode: 2)
        }
        return resolvedURL
    }

    /// 論理名（日本語）: 必須ページID取得関数
    /// 処理概要: `.ogp` 内 page または component を指定する `--page-id` / `--component-id` 参照 ID を取得します。
    ///
    /// - Parameter arguments: CLI 引数。
    /// - Returns: page または component の内部参照 ID。
    private func requiredPageID(in arguments: [String]) throws -> String {
        let pageID = try optionalOption("--page-id", in: arguments)
        let componentID = try optionalOption("--component-id", in: arguments)
        if pageID != nil && componentID != nil {
            throw OgkilnCLIError(message: "--page-id と --component-id は同時に指定できません。", exitCode: 2)
        }
        if let pageID {
            return pageID
        }
        if let componentID {
            return componentID
        }
        if let nodeReferenceID = try optionalOption("--id", in: arguments),
           let pageReferenceID = OpenGraphiteReferenceID.containingPageReferenceString(from: nodeReferenceID) {
            return pageReferenceID
        }
        throw OgkilnCLIError(message: "--page-id / --component-id または page を含む ogref の --id が指定されていません。", exitCode: 2)
    }

    /// 論理名（日本語）: 必須コンポーネントID取得関数
    /// 処理概要: `.ogp` の Collection 内 component canvas を指定する `--component-id` を取得します。
    ///
    /// - Parameter arguments: CLI 引数。
    /// - Returns: component ID。
    private func requiredComponentID(in arguments: [String]) throws -> String {
        try requiredOption("--component-id", in: arguments)
    }

    private func htmlFromFile(_ path: String, currentDirectory: URL) throws -> String {
        try String(contentsOf: url(for: path, currentDirectory: currentDirectory), encoding: .utf8)
    }

    private func textFromFile(_ path: String, currentDirectory: URL) throws -> String {
        try String(contentsOf: url(for: path, currentDirectory: currentDirectory), encoding: .utf8)
    }

    private func htmlOption(_ arguments: [String], currentDirectory: URL) throws -> String {
        try optionalOption("--html", in: arguments) ?? htmlFromFile(requiredOption("--html-file", in: arguments), currentDirectory: currentDirectory)
    }

    private func insertionPosition(from value: String) throws -> OpenGraphiteHTMLInsertionPosition {
        guard let position = OpenGraphiteHTMLInsertionPosition(rawValue: value) else {
            throw OgkilnCLIError(message: "--position は before / after / prepend / append のいずれかを指定してください。", exitCode: 2)
        }
        return position
    }

    static let helpText = """
    Usage:
      ogkiln contract get --json
      ogkiln project current --json
      ogkiln project inspect <project.ogp|current> --json
      ogkiln project page add <project.ogp|current> --page-id <page-id> --path <html-path> [--x <n>] [--y <n>] [--width <n>] [--height <n>] [--allow-duplicate-path]
      ogkiln project page create <project.ogp|current> --page-id <page-id> --path <html-path> --title <title> --body-file <body.html> [--lang <lang>] [--stylesheet <path>] [--overwrite]
      ogkiln project page create <project.ogp|current> --page-id <page-id> --path <html-path> --title <title> --body-html <body-html> [--lang <lang>] [--stylesheet <path>] [--overwrite]
      ogkiln project page place <project.ogp|current> --page-id <page-id> [--name <name>] [--x <n>] [--y <n>] [--width <n>] [--height <n>] [--preview-mock <key=value>]
      ogkiln project page document <project.ogp|current> --page-id <page-id> [--lang-source <literal|binding>] [--lang <lang>] [--lang-field <field>] [--dir-source <literal|auto|binding>] [--dir <ltr|rtl|auto>] [--dir-field <field>]
      ogkiln project component add <project.ogp|current> [--collection-id <collection-id>] --component-id <component-id> --path <html-path> [--x <n>] [--y <n>] [--width <n>] [--height <n>]
      ogkiln project component create <project.ogp|current> [--collection-id <collection-id>] --component-id <component-id> --path <html-path> --title <title> --body-file <body.html> [--lang <lang>] [--stylesheet <path>] [--overwrite]
      ogkiln project component create <project.ogp|current> [--collection-id <collection-id>] --component-id <component-id> --path <html-path> --title <title> --body-html <body-html> [--lang <lang>] [--stylesheet <path>] [--overwrite]
      ogkiln project component place <project.ogp|current> --component-id <component-id> [--name <name>] [--x <n>] [--y <n>] [--width <n>] [--height <n>] [--preview-mock <key=value>]
      ogkiln project component document <project.ogp|current> --component-id <component-id> [--lang-source <literal|binding>] [--lang <lang>] [--lang-field <field>] [--dir-source <literal|auto|binding>] [--dir <ltr|rtl|auto>] [--dir-field <field>]
      ogkiln project component remove <project.ogp|current> --component-id <component-id> [--delete-file]
      ogkiln page graph <project.ogp|current> --page-id <page-id>|--component-id <component-id> --json
      ogkiln i18n inspect <project.ogp|current> --page-id <page-id>|--component-id <component-id> [--locales <locale,locale>] --json
      ogkiln i18n recommend <project.ogp|current> --page-id <page-id>|--component-id <component-id> [--locales <locale,locale>]
      ogkiln i18n resource set <project.ogp|current> --page-id <page-id>|--component-id <component-id> --locale <locale> --key <i18n-key> --value <text>
      ogkiln i18n resource set <project.ogp|current> --page-id <page-id>|--component-id <component-id> --locale <locale> --key <i18n-key> --text-file <text-file>
      ogkiln validate <project.ogp|current> [--json]
      ogkiln build <project.ogp|current> --output <dir>
      ogkiln screenshot canvas <project.ogp|current> --output <png>
      ogkiln screenshot page <project.ogp|current> --page-id <page-id>|--component-id <component-id> --output <png> [--width <n>] [--height <n>] [--full-page]
      ogkiln screenshot node <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <node-id> --output <png> [--width <n>] [--height <n>] [--padding <n>]
      ogkiln node query <project.ogp|current> --page-id <page-id>|--component-id <component-id> [--id-contains <text>] [--type <type>] [--role <role>] [--tag <tag>] [--text-contains <text>] --json
      ogkiln node get <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <node-id> --json
      ogkiln node style set <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <node-id> --var <--og-var> --value <css-value>
      ogkiln node style remove <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <node-id> --var <--og-var>
      ogkiln node attr set <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <node-id> --name <data-og-attr> --value <value>
      ogkiln node attr remove <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <node-id> --name <data-og-attr>
      ogkiln node text set <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <node-id> --value <text>
      ogkiln node text set <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <node-id> --text-file <text-file>
      ogkiln text variant set <project.ogp|current> --page-id <page-id>|--component-id <component-id> --key <data-i18n-key> --locale <locale> --value <text>
      ogkiln text variant set <project.ogp|current> --page-id <page-id>|--component-id <component-id> --key <data-i18n-key> --locale <locale> --text-file <text-file>
      ogkiln node html insert <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <anchor-node-id> --position <before|after|prepend|append> --html <fragment-html>
      ogkiln node html insert <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <anchor-node-id> --position <before|after|prepend|append> --html-file <fragment.html>
      ogkiln node html replace <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <node-id> --html <replacement-html>
      ogkiln node html replace <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <node-id> --html-file <replacement.html>
      ogkiln node delete <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <node-id>
      ogkiln node move <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <source-node-id> --target <target-node-id> --position <before|after|prepend|append>
      ogkiln node copy <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <source-node-id> --target <target-node-id> --position <before|after|prepend|append> --id-prefix <prefix>
    """
}

/// 論理名（日本語）: ogkiln出力
/// 概要: JSON 文字列とプロセス終了コードをまとめて保持します。
///
/// プロパティ:
/// - `json`: 標準出力へ書く JSON。
/// - `exitCode`: プロセス終了コード。
struct OgkilnOutput {
    var json: String
    var exitCode: Int32

    /// 論理名（日本語）: JSON出力初期化関数
    /// 処理概要: Encodable object を安定した pretty JSON へ変換します。
    ///
    /// - Parameters:
    ///   - object: JSON へ変換する値。
    ///   - exitCode: プロセス終了コード。
    init<T: Encodable>(object: T, exitCode: Int32) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(object)
        json = String(data: data, encoding: .utf8) ?? "{}"
        self.exitCode = exitCode
    }
}

/// 論理名（日本語）: ogkiln CLIエラー
/// 概要: CLI 引数エラーや実行エラーの表示メッセージと終了コードを表します。
///
/// プロパティ:
/// - `message`: 標準エラーへ表示する文字列。
/// - `exitCode`: プロセス終了コード。
struct OgkilnCLIError: Error {
    var message: String
    var exitCode: Int32
}
