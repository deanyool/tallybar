import Foundation
import Testing
@testable import TallyCore

@Suite("Totals")
struct TotalsTests {
    private let calendar = Fixtures.calendar()

    private func add(_ ledger: inout Ledger, _ client: Client, _ start: String, _ end: String) {
        ledger.entries.append(TimeEntry(clientID: client.id, start: Fixtures.at(start), end: Fixtures.at(end)))
    }

    @Test func midnightCrossingCountsTowardEachDay() {
        var (ledger, client) = Fixtures.ledger()
        add(&ledger, client, "2025-10-15T23:00:00-04:00", "2025-10-16T01:30:00-04:00")
        let now = Fixtures.at("2025-10-16T12:00:00-04:00")
        let wednesday = calendar.dayInterval(containing: Fixtures.at("2025-10-15T12:00:00-04:00"))
        let thursday = calendar.dayInterval(containing: now)
        #expect(ledger.seconds(in: wednesday, at: now) == 3600)
        #expect(ledger.seconds(in: thursday, at: now) == 5400)
    }

    @Test func weekBoundaryCrossingCountsTowardEachWeek() {
        var (ledger, client) = Fixtures.ledger()
        add(&ledger, client, "2025-10-19T23:00:00-04:00", "2025-10-20T01:00:00-04:00")
        let now = Fixtures.at("2025-10-22T12:00:00-04:00")
        let lastWeek = calendar.weekInterval(containing: Fixtures.at("2025-10-19T12:00:00-04:00"))
        let thisWeek = calendar.weekInterval(containing: now)
        #expect(ledger.seconds(in: lastWeek, at: now) == 3600)
        #expect(ledger.seconds(in: thisWeek, at: now) == 3600)
    }

    @Test func runningSessionCountsUpToNow() {
        var (ledger, client) = Fixtures.ledger()
        let start = Fixtures.at("2025-10-15T09:00:00-04:00")
        ledger.start(clientID: client.id, at: start)
        let now = start.addingTimeInterval(1500)
        #expect(ledger.seconds(in: calendar.dayInterval(containing: now), at: now) == 1500)
    }

    @Test func filtersByClient() {
        var (ledger, client) = Fixtures.ledger()
        let other = ledger.addClient(name: "Other", hourlyRate: 10)
        add(&ledger, client, "2025-10-15T09:00:00-04:00", "2025-10-15T10:00:00-04:00")
        add(&ledger, other, "2025-10-15T11:00:00-04:00", "2025-10-15T11:30:00-04:00")
        let now = Fixtures.at("2025-10-15T12:00:00-04:00")
        #expect(ledger.seconds(in: calendar.dayInterval(containing: now), clientID: other.id, at: now) == 1800)
    }

    @Test func noTimeMeansNoEarningsRows() {
        let (ledger, _) = Fixtures.ledger()
        let now = Fixtures.at("2025-10-15T12:00:00-04:00")
        #expect(ledger.earnings(in: calendar.dayInterval(containing: now), at: now).isEmpty)
    }

    @Test func clippingOutsideTheIntervalIsNil() {
        let entry = TimeEntry(
            clientID: UUID(),
            start: Fixtures.at("2025-10-15T09:00:00-04:00"),
            end: Fixtures.at("2025-10-15T10:00:00-04:00")
        )
        let later = DateInterval(start: Fixtures.at("2025-10-15T10:00:00-04:00"), duration: 3600)
        #expect(entry.clipped(to: later) == nil)
    }
}
