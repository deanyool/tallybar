import Foundation
import Testing
@testable import TallyCore

@Suite("Timesheet")
struct TimesheetTests {
    private let calendar = Fixtures.calendar()
    private let october = DateInterval(
        start: Fixtures.at("2025-10-01T00:00:00-04:00"),
        end: Fixtures.at("2025-11-01T00:00:00-04:00")
    )

    private func entry(_ client: Client, _ start: String, _ end: String, note: String = "") -> TimeEntry {
        TimeEntry(clientID: client.id, start: Fixtures.at(start), end: Fixtures.at(end), note: note)
    }

    @Test func groupsNewestDayFirstAndOldestRowFirst() {
        var (ledger, client) = Fixtures.ledger()
        ledger.entries = [
            entry(client, "2025-10-15T14:00:00-04:00", "2025-10-15T15:00:00-04:00", note: "second"),
            entry(client, "2025-10-15T09:00:00-04:00", "2025-10-15T10:00:00-04:00", note: "first"),
            entry(client, "2025-10-16T09:00:00-04:00", "2025-10-16T10:00:00-04:00", note: "next day")
        ]
        let days = ledger.timesheet(in: october, calendar: calendar)
        #expect(days.map { $0.rows.map(\.entry.note) } == [["next day"], ["first", "second"]])
        #expect(days[1].seconds == 7200)
    }

    @Test func midnightCrossingAppearsUnderBothDays() throws {
        var (ledger, client) = Fixtures.ledger()
        ledger.entries = [
            entry(client, "2025-10-15T23:00:00-04:00", "2025-10-16T00:30:00-04:00")
        ]
        let days = ledger.timesheet(in: october, calendar: calendar)
        #expect(days.count == 2)
        let later = try #require(days[0].rows.first)
        let earlier = try #require(days[1].rows.first)
        #expect(earlier.seconds == 3600)
        #expect(earlier.continuesToNextDay && !earlier.continuesFromPreviousDay)
        #expect(later.seconds == 1800)
        #expect(later.continuesFromPreviousDay && !later.continuesToNextDay)
        #expect(earlier.id != later.id)
    }

    @Test func filtersByClientAndPeriod() {
        var (ledger, client) = Fixtures.ledger()
        let other = ledger.addClient(name: "Other", hourlyRate: 1)
        ledger.entries = [
            entry(client, "2025-10-15T09:00:00-04:00", "2025-10-15T10:00:00-04:00"),
            entry(other, "2025-10-15T11:00:00-04:00", "2025-10-15T12:00:00-04:00"),
            entry(client, "2025-09-15T09:00:00-04:00", "2025-09-15T10:00:00-04:00")
        ]
        let days = ledger.timesheet(in: october, clientID: client.id, calendar: calendar)
        #expect(days.count == 1)
        #expect(days[0].rows.count == 1)
    }
}

@Suite("Editing entries")
struct EntryEditingTests {
    private let nine = Fixtures.at("2025-10-15T09:00:00-04:00")
    private let ten = Fixtures.at("2025-10-15T10:00:00-04:00")
    private let eleven = Fixtures.at("2025-10-15T11:00:00-04:00")

    @Test func addsAManualEntry() throws {
        var (ledger, client) = Fixtures.ledger()
        try ledger.save(TimeEntry(clientID: client.id, start: nine, end: ten))
        #expect(ledger.entries.count == 1)
    }

    @Test func editReplacesTheEntry() throws {
        var (ledger, client) = Fixtures.ledger()
        var entry = TimeEntry(clientID: client.id, start: nine, end: ten)
        try ledger.save(entry)
        entry.end = eleven
        try ledger.save(entry)
        #expect(ledger.entries.count == 1)
        #expect(ledger.entries[0].end == eleven)
    }

    @Test func refusesBackwardEntries() {
        var (ledger, client) = Fixtures.ledger()
        #expect(throws: EntryProblem.endNotAfterStart) {
            try ledger.save(TimeEntry(clientID: client.id, start: ten, end: nine))
        }
    }

    @Test func refusesUnknownClients() {
        var (ledger, _) = Fixtures.ledger()
        #expect(throws: EntryProblem.unknownClient) {
            try ledger.save(TimeEntry(clientID: UUID(), start: nine, end: ten))
        }
    }

    @Test func refusesOverlaps() throws {
        var (ledger, client) = Fixtures.ledger()
        let first = TimeEntry(clientID: client.id, start: nine, end: eleven)
        try ledger.save(first)
        #expect(throws: EntryProblem.overlaps(first)) {
            try ledger.save(TimeEntry(clientID: client.id, start: ten, end: eleven.addingTimeInterval(60)))
        }
    }

    @Test func touchingEntriesAreNotAnOverlap() throws {
        var (ledger, client) = Fixtures.ledger()
        try ledger.save(TimeEntry(clientID: client.id, start: nine, end: ten))
        try ledger.save(TimeEntry(clientID: client.id, start: ten, end: eleven))
        #expect(ledger.entries.count == 2)
    }

    @Test func invoicedEntriesCannotChange() throws {
        var (ledger, client) = Fixtures.ledger()
        var entry = TimeEntry(clientID: client.id, start: nine, end: ten)
        try ledger.save(entry)
        ledger.entries[0].invoiceNumber = "INV-0001"
        entry.end = eleven
        #expect(throws: EntryProblem.alreadyInvoiced("INV-0001")) { try ledger.save(entry) }
        #expect(throws: EntryProblem.alreadyInvoiced("INV-0001")) { try ledger.deleteEntry(id: entry.id) }
    }

    @Test func deleteRemovesTheEntry() throws {
        var (ledger, client) = Fixtures.ledger()
        let entry = TimeEntry(clientID: client.id, start: nine, end: ten)
        try ledger.save(entry)
        try ledger.deleteEntry(id: entry.id)
        #expect(ledger.entries.isEmpty)
    }

    @Test func newestFirstSorts() throws {
        var (ledger, client) = Fixtures.ledger()
        try ledger.save(TimeEntry(clientID: client.id, start: nine, end: ten))
        try ledger.save(TimeEntry(clientID: client.id, start: ten, end: eleven))
        #expect(ledger.entriesNewestFirst.first?.start == ten)
    }

    @Test func problemsReadAsSentences() {
        #expect(EntryProblem.alreadyInvoiced("INV-7").description.contains("INV-7"))
        #expect(EntryProblem.endNotAfterStart.description.hasSuffix("."))
    }
}
