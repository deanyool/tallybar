import Foundation

/// Reads and writes the ledger as one JSON file. Writes are atomic: the data goes to a
/// temporary file which then replaces the old one, so a crash mid-save cannot leave a
/// half-written ledger.
public struct LedgerStore: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// `~/Library/Application Support/TallyBar/ledger.json`
    public static var defaultURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "TallyBar", directoryHint: .isDirectory)
            .appending(path: "ledger.json", directoryHint: .notDirectory)
    }

    public func load() throws -> Ledger {
        guard FileManager.default.fileExists(atPath: url.path) else { return Ledger() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Ledger.self, from: Data(contentsOf: url))
    }

    public func save(_ ledger: Ledger) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(ledger).write(to: url, options: .atomic)
    }
}
