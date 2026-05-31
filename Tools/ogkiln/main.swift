import Foundation

let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let exitCode = OgkilnCLI().run(
    arguments: Array(CommandLine.arguments.dropFirst()),
    currentDirectory: currentDirectory,
    stdout: { print($0) },
    stderr: { FileHandle.standardError.write(Data(($0 + "\n").utf8)) }
)
exit(exitCode)
