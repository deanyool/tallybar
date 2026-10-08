import Foundation

public enum LedgerStoreError: Error, Equatable, CustomStringConvertible {
    /// The file was written by a newer TallyBar. Loading it would drop fields on save.
    case newerVersion(found: Int, supported: Int)

    public var description: String {
        switch self {
        case let .newerVersion(found, supported):
            return "This data file is version \(found), but this copy of TallyBar reads up to "
                + "version \(supported). Update TallyBar to open it."
        }
    }
}

/// What happened when the ledger was loaded.
public enum LedgerLoadOutcome: Equatable, Sendable {
    case fresh
    case loaded
    /// The main file was unreadable. It was moved to `quarantined`, never removed.
    case recovered(usedBackup: Bool, quarantined: URL)
}

/// Reads and writes the ledger as one JSON file. Writes are atomic: the data goes to a
/// temporary file which then replaces the old one, so a crash mid-save cannot leave a
/// half-written ledger. The previous good file is kept next to it as a backup.
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

    public var backupURL: URL {
        url.deletingPathExtension().appendingPathExtension("backup.json")
    }

    public func load() throws -> (ledger: Ledger, outcome: LedgerLoadOutcome) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return (Ledger(), .fresh)
        }
        do {
            return (try decode(url), .loaded)
        } catch let error as LedgerStoreError {
            throw error
        } catch {
            let quarantined = try quarantine()
            if let backup = try? decode(backupURL) {
                return (backup, .recovered(usedBackup: true, quarantined: quarantined))
            }
            return (Ledger(), .recovered(usedBackup: false, quarantined: quarantined))
        }
    }

    public func save(_ ledger: Ledger) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if manager.fileExists(atPath: url.path), (try? decode(url)) != nil {
            let previous = try Data(contentsOf: url)
            try previous.write(to: backupURL, options: .atomic)
        }
        try LedgerStore.encoder.encode(ledger).write(to: url, options: .atomic)
    }

    private func decode(_ source: URL) throws -> Ledger {
        let data = try Data(contentsOf: source)
        var ledger = try LedgerStore.decoder.decode(Ledger.self, from: data)
        guard ledger.version <= Ledger.currentVersion else {
            throw LedgerStoreError.newerVersion(found: ledger.version, supported: Ledger.currentVersion)
        }
        ledger.version = Ledger.currentVersion
        return ledger
    }

    private func quarantine() throws -> URL {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let target = url.deletingPathExtension().appendingPathExtension("corrupt-\(stamp).json")
        try FileManager.default.moveItem(at: url, to: target)
        return target
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
