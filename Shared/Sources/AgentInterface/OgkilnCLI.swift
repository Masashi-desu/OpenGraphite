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
                    canvas: canvas
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
                    x: try doubleOption("--x", in: arguments),
                    y: try doubleOption("--y", in: arguments),
                    width: try doubleOption("--width", in: arguments),
                    height: try doubleOption("--height", in: arguments)
                )
                return try OgkilnOutput(object: summary, exitCode: summary.diagnostics.contains { $0.severity == .error } ? 1 : 0)
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
                    x: try doubleOption("--x", in: arguments),
                    y: try doubleOption("--y", in: arguments),
                    width: try doubleOption("--width", in: arguments),
                    height: try doubleOption("--height", in: arguments)
                )
                return try OgkilnOutput(object: summary, exitCode: summary.diagnostics.contains { $0.severity == .error } ? 1 : 0)
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
                padding: try doubleOption("--padding", in: arguments)
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
    /// 処理概要: `.ogp` 内 page または component を指定する `--page-id` / `--component-id` を取得します。
    ///
    /// - Parameter arguments: CLI 引数。
    /// - Returns: page または component ID。
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
        throw OgkilnCLIError(message: "--page-id または --component-id が指定されていません。", exitCode: 2)
    }

    /// 論理名（日本語）: 必須コンポーネントID取得関数
    /// 処理概要: `.ogp` の Components セグメントを指定する `--component-id` を取得します。
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
      ogkiln project page add <project.ogp|current> --page-id <page-id> --path <html-path> [--x <n>] [--y <n>] [--width <n>] [--height <n>]
      ogkiln project page create <project.ogp|current> --page-id <page-id> --path <html-path> --title <title> --body-file <body.html> [--lang <lang>] [--stylesheet <path>] [--overwrite]
      ogkiln project page create <project.ogp|current> --page-id <page-id> --path <html-path> --title <title> --body-html <body-html> [--lang <lang>] [--stylesheet <path>] [--overwrite]
      ogkiln project page place <project.ogp|current> --page-id <page-id> [--x <n>] [--y <n>] [--width <n>] [--height <n>]
      ogkiln project component add <project.ogp|current> --component-id <component-id> --path <html-path> [--x <n>] [--y <n>] [--width <n>] [--height <n>]
      ogkiln project component create <project.ogp|current> --component-id <component-id> --path <html-path> --title <title> --body-file <body.html> [--lang <lang>] [--stylesheet <path>] [--overwrite]
      ogkiln project component create <project.ogp|current> --component-id <component-id> --path <html-path> --title <title> --body-html <body-html> [--lang <lang>] [--stylesheet <path>] [--overwrite]
      ogkiln project component place <project.ogp|current> --component-id <component-id> [--x <n>] [--y <n>] [--width <n>] [--height <n>]
      ogkiln project component remove <project.ogp|current> --component-id <component-id> [--delete-file]
      ogkiln page graph <project.ogp|current> --page-id <page-id>|--component-id <component-id> --json
      ogkiln validate <project.ogp|current> [--json]
      ogkiln build <project.ogp|current> --output <dir>
      ogkiln screenshot canvas <project.ogp|current> --output <png>
      ogkiln screenshot page <project.ogp|current> --page-id <page-id>|--component-id <component-id> --output <png> [--width <n>] [--height <n>] [--full-page]
      ogkiln screenshot node <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <data-og-id> --output <png> [--width <n>] [--height <n>] [--padding <n>]
      ogkiln node query <project.ogp|current> --page-id <page-id>|--component-id <component-id> [--id-contains <text>] [--type <type>] [--role <role>] [--tag <tag>] [--text-contains <text>] --json
      ogkiln node get <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <data-og-id> --json
      ogkiln node style set <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <data-og-id> --var <--og-var> --value <css-value>
      ogkiln node style remove <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <data-og-id> --var <--og-var>
      ogkiln node attr set <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <data-og-id> --name <data-og-attr> --value <value>
      ogkiln node attr remove <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <data-og-id> --name <data-og-attr>
      ogkiln node text set <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <data-og-id> --value <text>
      ogkiln node text set <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <data-og-id> --text-file <text-file>
      ogkiln node html insert <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <anchor-data-og-id> --position <before|after|prepend|append> --html <fragment-html>
      ogkiln node html insert <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <anchor-data-og-id> --position <before|after|prepend|append> --html-file <fragment.html>
      ogkiln node html replace <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <data-og-id> --html <replacement-html>
      ogkiln node html replace <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <data-og-id> --html-file <replacement.html>
      ogkiln node delete <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <data-og-id>
      ogkiln node move <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <source-data-og-id> --target <target-data-og-id> --position <before|after|prepend|append>
      ogkiln node copy <project.ogp|current> --page-id <page-id>|--component-id <component-id> --id <source-data-og-id> --target <target-data-og-id> --position <before|after|prepend|append> --id-prefix <prefix>
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
