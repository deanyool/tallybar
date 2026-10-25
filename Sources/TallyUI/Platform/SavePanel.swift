import AppKit
import UniformTypeIdentifiers

/// The real `ChooseSaveURL`: a standard save panel. This is the one piece of the export
/// and invoice flows that tests cannot reach.
@MainActor
enum SavePanel {
    static func choose(suggestedName: String, type: UTType) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = suggestedName
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
