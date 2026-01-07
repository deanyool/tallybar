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

    @Test func groupsNewestDayFirstAndOldestRowFirst() {
        var (ledger, client) = Fixtures.ledger()
        ledger.entries = [
            TimeEntry(clientID: client.id, start: Fixtures.at("2025-10-15T14:00:00-04:00"), end: Fixtures.at("2025-10-15T15:00:00-04:00"), note: "second"),
            TimeEntry(clientID: client.id, start: Fixtures.at("2025-10-15T09:00:00-04:00"), end: Fixtures.at("2025-10-15T10:00:00-04:00"), note: "first"),
            TimeEntry(clientID: client.id, start: Fixtures.at("2025-10-16T09:00:00-04:00"), end: Fixtures.at("2025-10-16T10:00:00-04:00"), note: "next day")
        ]
        let days = ledger.timesheet(in: october, calendar: calendar)
        #expect(days.map { $0.rows.map(\.entry.note) } == [["next day"], ["first", "second"]])
        #expect(days[1].seconds == 7200)
    }

    @Test func midnightCrossingAppearsUnderBothDays() throws {
        var (ledger, client) = Fixtures.ledger()
        ledger.entries = [
            TimeEntry(clientID: client.id, start: Fixtures.at("2025-10-15T23:00:00-04:00"), end: Fixtures.at("2025-10-16T00:30:00-04:00"))
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
            TimeEntry(clientID: client.id, start: Fixtures.at("2025-10-15T09:00:00-04:00"), end: Fixtures.at("2025-10-15T10:00:00-04:00")),
            TimeEntry(clientID: other.id, start: Fixtures.at("2025-10-15T11:00:00-04:00"), end: Fixtures.at("2025-10-15T12:00:00-04:00")),
            TimeEntry(clientID: client.id, start: Fixtures.at("2025-09-15T09:00:00-04:00"), end: Fixtures.at("2025-09-15T10:00:00-04:00"))
        ]
        let days = ledger.timesheet(in: october, clientID: client.id, calendar: calendar)
        #expect(days.count == 1)
        #expect(days[0].rows.count == 1)
    }
}
