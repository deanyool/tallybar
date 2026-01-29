import Foundation
import Testing
@testable import TallyCore

@Suite("Storage")
struct StoreTests {
    private func store() -> LedgerStore {
        LedgerStore(url: Fixtures.temporaryDirectory().appending(path: "nested/ledger.json"))
    }

    private func sampleLedger() -> Ledger {
        var (ledger, client) = Fixtures.ledger(rate: Decimal(string: "133.37")!)
        ledger.entries.append(TimeEntry(
            clientID: client.id,
            start: Fixtures.at("2025-11-02T01:30:00-04:00"),
            end: Fixtures.at("2025-11-02T01:30:00-05:00"),
            note: "Crossed the fall-back hour, with \"quotes\" and ünïcode"
        ))
        ledger.start(clientID: client.id, note: "Still going", at: Fixtures.at("2025-11-03T09:00:00-05:00"))
        return ledger
    }

    @Test func missingFileMeansFreshLedger() throws {
        let (ledger, outcome) = try store().load()
        #expect(ledger == Ledger())
        #expect(outcome == .fresh)
    }

    @Test func roundTripsEverything() throws {
        let store = store()
        let original = sampleLedger()
        try store.save(original)
        let (loaded, outcome) = try store.load()
        #expect(loaded == original)
        #expect(outcome == .loaded)
    }

    @Test func runningSessionSurvivesARestart() throws {
        let store = store()
        try store.save(sampleLedger())
        #expect(try store.load().ledger.running?.note == "Still going")
    }

    @Test func fileIsReadableJSON() throws {
        let store = store()
        try store.save(sampleLedger())
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: store.url)) as? [String: Any]
        #expect(object?["version"] as? Int == Ledger.currentVersion)
    }

    @Test func savingKeepsThePreviousVersionAsBackup() throws {
        let store = store()
        var ledger = Ledger()
        ledger.addClient(name: "First", hourlyRate: 10)
        try store.save(ledger)
        ledger.addClient(name: "Second", hourlyRate: 10)
        try store.save(ledger)
        let backup = try JSONDecoder.forTests.decode(Ledger.self, from: Data(contentsOf: store.backupURL))
        #expect(backup.clients.count == 1)
    }

    @Test func corruptFileIsQuarantinedAndTheBackupRestored() throws {
        let store = store()
        var ledger = Ledger()
        ledger.addClient(name: "Kept", hourlyRate: 10)
        try store.save(ledger)
        ledger.addClient(name: "Newer", hourlyRate: 10)
        try store.save(ledger)
        let garbage = Data("{ not json".utf8)
        try garbage.write(to: store.url)

        let (loaded, outcome) = try store.load()
        #expect(loaded.clients.map(\.name) == ["Kept"])
        guard case let .recovered(usedBackup, quarantined) = outcome else {
            Issue.record("expected recovery, got \(outcome)")
            return
        }
        #expect(usedBackup)
        #expect(try Data(contentsOf: quarantined) == garbage)
    }

    @Test func corruptFileWithNoBackupStartsEmptyButKeepsTheFile() throws {
        let store = store()
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("garbage".utf8).write(to: store.url)
        let (loaded, outcome) = try store.load()
        #expect(loaded == Ledger())
        guard case let .recovered(usedBackup, quarantined) = outcome else {
            Issue.record("expected recovery, got \(outcome)")
            return
        }
        #expect(!usedBackup)
        #expect(FileManager.default.fileExists(atPath: quarantined.path))
    }

    @Test func refusesFilesFromTheFuture() throws {
        let store = store()
        var ledger = Ledger()
        ledger.version = Ledger.currentVersion + 1
        try store.save(ledger)
        #expect(throws: LedgerStoreError.newerVersion(found: ledger.version, supported: Ledger.currentVersion)) {
            try store.load()
        }
    }

    @Test func oldFilesPickUpDefaultsForNewSettings() throws {
        let store = store()
        let json = #"{"version": 1, "clients": [], "entries": [], "settings": {"weeklyGoalHours": 12}}"#
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(json.utf8).write(to: store.url)
        let settings = try store.load().ledger.settings
        #expect(settings.weeklyGoalHours == 12)
        #expect(settings.idleThresholdMinutes == TallySettings().idleThresholdMinutes)
    }

    @Test func defaultLocationIsApplicationSupport() {
        #expect(LedgerStore.defaultURL.path.hasSuffix("Application Support/TallyBar/ledger.json"))
    }
}

private extension JSONDecoder {
    static var forTests: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
