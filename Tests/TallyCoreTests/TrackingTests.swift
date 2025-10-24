import Foundation
import Testing
@testable import TallyCore

@Suite("Starting, stopping and switching")
struct TrackingTests {
    private let t0 = Fixtures.at("2025-10-15T09:00:00-04:00")

    @Test func startThenStopRecordsAnEntry() throws {
        var (ledger, client) = Fixtures.ledger()
        ledger.start(clientID: client.id, note: "Design", at: t0)
        #expect(ledger.running?.clientID == client.id)
        let stopped = ledger.stop(at: t0.addingTimeInterval(1800))
        let entry = try #require(stopped)
        #expect(entry.seconds == 1800)
        #expect(entry.note == "Design")
        #expect(ledger.running == nil)
        #expect(ledger.entries == [entry])
    }

    @Test func switchingClosesThePreviousSessionAtTheSameInstant() {
        var (ledger, first) = Fixtures.ledger()
        let second = ledger.addClient(name: "Second", hourlyRate: 50)
        ledger.start(clientID: first.id, at: t0)
        let switchTime = t0.addingTimeInterval(600)
        ledger.start(clientID: second.id, at: switchTime)
        #expect(ledger.entries.count == 1)
        #expect(ledger.entries[0].end == switchTime)
        #expect(ledger.running?.clientID == second.id)
        #expect(ledger.running?.start == switchTime)
    }

    @Test func startingTheRunningClientChangesNothing() {
        var (ledger, client) = Fixtures.ledger()
        ledger.start(clientID: client.id, at: t0)
        let before = ledger
        ledger.start(clientID: client.id, at: t0.addingTimeInterval(60))
        #expect(ledger == before)
    }

    @Test func startingAnUnknownClientChangesNothing() {
        var (ledger, _) = Fixtures.ledger()
        ledger.start(clientID: UUID(), at: t0)
        #expect(ledger.running == nil)
    }

    @Test func stopWithNothingRunningIsHarmless() {
        var (ledger, _) = Fixtures.ledger()
        #expect(ledger.stop(at: t0) == nil)
        #expect(ledger.entries.isEmpty)
    }

    @Test func timesAreWholeSeconds() {
        var (ledger, client) = Fixtures.ledger()
        ledger.start(clientID: client.id, at: t0.addingTimeInterval(0.7))
        ledger.stop(at: t0.addingTimeInterval(120.9))
        #expect(ledger.entries[0].start == t0)
        #expect(ledger.entries[0].end == t0.addingTimeInterval(120))
    }

    @Test func toggleResumesTheLastClient() {
        var (ledger, first) = Fixtures.ledger()
        let second = ledger.addClient(name: "Second", hourlyRate: 50)
        ledger.start(clientID: second.id, at: t0)
        ledger.toggle(at: t0.addingTimeInterval(60))
        #expect(ledger.running == nil)
        ledger.toggle(at: t0.addingTimeInterval(120))
        #expect(ledger.running?.clientID == second.id)
        #expect(first.id != second.id)
    }

    @Test func toggleSkipsAnArchivedLastClient() {
        var (ledger, first) = Fixtures.ledger()
        let second = ledger.addClient(name: "Second", hourlyRate: 50)
        ledger.start(clientID: second.id, at: t0)
        ledger.archiveClient(id: second.id, at: t0.addingTimeInterval(60))
        ledger.toggle(at: t0.addingTimeInterval(120))
        #expect(ledger.running?.clientID == first.id)
    }

    @Test func toggleWithNoClientsDoesNothing() {
        var ledger = Ledger()
        ledger.toggle(at: t0)
        #expect(ledger.running == nil)
    }

    @Test func runningSessionNoteCanChange() {
        var (ledger, client) = Fixtures.ledger()
        ledger.start(clientID: client.id, at: t0)
        ledger.setRunningNote("Changed my mind")
        ledger.stop(at: t0.addingTimeInterval(60))
        #expect(ledger.entries[0].note == "Changed my mind")
    }

    @Test func archivingStopsTheTimer() {
        var (ledger, client) = Fixtures.ledger()
        ledger.start(clientID: client.id, at: t0)
        ledger.archiveClient(id: client.id, at: t0.addingTimeInterval(300))
        #expect(ledger.running == nil)
        #expect(ledger.entries.count == 1)
        #expect(ledger.activeClients.isEmpty)
        ledger.unarchiveClient(id: client.id)
        #expect(ledger.activeClients.count == 1)
    }

    @Test func newClientsCycleColors() {
        var ledger = Ledger()
        let first = ledger.addClient(name: "  One  ", hourlyRate: 10)
        let second = ledger.addClient(name: "Two", hourlyRate: 10)
        #expect(first.name == "One")
        #expect(first.colorIndex != second.colorIndex)
    }

    @Test func addClientUsesTheDefaultCurrency() {
        var ledger = Ledger()
        ledger.settings.defaultCurrency = "CAD"
        #expect(ledger.addClient(name: "One", hourlyRate: 10).hourlyRate.currency == "CAD")
    }
}
