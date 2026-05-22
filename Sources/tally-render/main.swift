import Foundation

// Renders the real SwiftUI views and the real invoice renderer from a fictional ledger.
// Usage: tally-render <output-directory>
let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    print("usage: tally-render <output-directory>")
    exit(2)
}
let output = URL(filePath: arguments[1], directoryHint: .isDirectory)
do {
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    try Renderer(output: output).renderAll()
} catch {
    print("failed: \(error)")
    exit(1)
}
