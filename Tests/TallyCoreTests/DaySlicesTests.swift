import Foundation
import Testing
@testable import TallyCore

@Suite("Day boundaries and daylight saving")
struct DaySlicesTests {
    private func hours(_ slice: DaySlice) -> Double {
        Double(slice.seconds) / 3600
    }

    @Test func spanInsideOneDayIsOneSlice() {
        let start = Fixtures.at("2025-10-15T09:00:00-04:00")
        let slices = Fixtures.calendar().daySlices(from: start, to: start.addingTimeInterval(3600))
        #expect(slices.count == 1)
        #expect(slices[0].seconds == 3600)
    }

    @Test func splitsAtMidnight() {
        let slices = Fixtures.calendar().daySlices(
            from: Fixtures.at("2025-10-15T22:30:00-04:00"),
            to: Fixtures.at("2025-10-16T00:45:00-04:00")
        )
        #expect(slices.map(\.seconds) == [90 * 60, 45 * 60])
        #expect(slices[1].day == Fixtures.at("2025-10-16T00:00:00-04:00"))
    }

    @Test func endingExactlyAtMidnightStaysOnOneDay() {
        let slices = Fixtures.calendar().daySlices(
            from: Fixtures.at("2025-10-15T23:00:00-04:00"),
            to: Fixtures.at("2025-10-16T00:00:00-04:00")
        )
        #expect(slices.count == 1)
    }

    @Test func emptySpanHasNoSlices() {
        let date = Fixtures.at("2025-10-15T23:00:00-04:00")
        #expect(Fixtures.calendar().daySlices(from: date, to: date).isEmpty)
    }

    @Test func multiDaySpanCoversEveryDay() {
        let slices = Fixtures.calendar().daySlices(
            from: Fixtures.at("2025-10-15T12:00:00-04:00"),
            to: Fixtures.at("2025-10-18T12:00:00-04:00")
        )
        #expect(slices.map(hours) == [12, 24, 24, 12])
    }

    @Test func fallBackDayHasTwentyFiveHours() {
        // Toronto, Nov 2 2025: 02:00 EDT falls back to 01:00 EST.
        let slices = Fixtures.calendar().daySlices(
            from: Fixtures.at("2025-11-01T23:00:00-04:00"),
            to: Fixtures.at("2025-11-03T01:00:00-05:00")
        )
        #expect(slices.map(hours) == [1, 25, 1])
    }

    @Test func springForwardDayHasTwentyThreeHours() {
        // Toronto, Mar 8 2026: 02:00 EST jumps to 03:00 EDT.
        let slices = Fixtures.calendar().daySlices(
            from: Fixtures.at("2026-03-07T23:00:00-05:00"),
            to: Fixtures.at("2026-03-09T01:00:00-04:00")
        )
        #expect(slices.map(hours) == [1, 23, 1])
    }

    @Test func sessionThroughTheRepeatedHourCountsRealTime() {
        // 00:30 EDT to 01:30 EST reads as one wall-clock hour but is two real hours.
        let entry = TimeEntry(
            clientID: UUID(),
            start: Fixtures.at("2025-11-02T00:30:00-04:00"),
            end: Fixtures.at("2025-11-02T01:30:00-05:00")
        )
        #expect(entry.seconds == 2 * 3600)
    }

    @Test func sessionThroughTheSkippedHourCountsRealTime() {
        // 01:30 EST to 03:30 EDT reads as two wall-clock hours but is one real hour.
        let entry = TimeEntry(
            clientID: UUID(),
            start: Fixtures.at("2026-03-08T01:30:00-05:00"),
            end: Fixtures.at("2026-03-08T03:30:00-04:00")
        )
        #expect(entry.seconds == 3600)
    }

    @Test func zoneWhereMidnightDoesNotExist() {
        // Havana, Mar 8 2026: 00:00 jumps to 01:00, so the day starts at 01:00.
        let havana = Fixtures.calendar(Fixtures.zone("America/Havana"))
        let slices = havana.daySlices(
            from: Fixtures.at("2026-03-07T23:30:00-05:00"),
            to: Fixtures.at("2026-03-08T01:30:00-04:00")
        )
        #expect(slices.count == 2)
        #expect(slices.map(\.seconds) == [1800, 1800])
        #expect(slices[1].day == Fixtures.at("2026-03-08T01:00:00-04:00"))
    }

    @Test func halfHourDaylightSavingZone() {
        // Lord Howe, Oct 5 2025: clocks move 30 minutes, making a 23.5 hour day.
        let lordHowe = Fixtures.calendar(Fixtures.zone("Australia/Lord_Howe"))
        let day = lordHowe.dayInterval(containing: Fixtures.at("2025-10-05T12:00:00+11:00"))
        #expect(day.duration == 23.5 * 3600)
    }

    @Test(arguments: ["America/Toronto", "Europe/London", "Asia/Kathmandu", "Australia/Lord_Howe", "America/Havana"])
    func slicesAlwaysAddUpToTheSpan(zone: String) {
        let calendar = Fixtures.calendar(Fixtures.zone(zone))
        var start = Fixtures.at("2025-01-01T00:00:00Z")
        for step in 1...400 {
            let length = step * 7919
            let end = start.addingTimeInterval(TimeInterval(length))
            let slices = calendar.daySlices(from: start, to: end)
            #expect(slices.reduce(0) { $0 + $1.seconds } == length)
            start = start.addingTimeInterval(86_400 + 3607)
        }
    }

    @Test func weekFollowsFirstWeekday() {
        let thursday = Fixtures.at("2025-10-16T12:00:00-04:00")
        #expect(Fixtures.calendar(firstWeekday: 2).weekInterval(containing: thursday).start
            == Fixtures.at("2025-10-13T00:00:00-04:00"))
        #expect(Fixtures.calendar(firstWeekday: 1).weekInterval(containing: thursday).start
            == Fixtures.at("2025-10-12T00:00:00-04:00"))
    }

    @Test func weekContainingFallBackIsOneHourLonger() {
        let week = Fixtures.calendar().weekInterval(containing: Fixtures.at("2025-11-01T12:00:00-04:00"))
        #expect(week.duration == 7 * 86_400 + 3600)
    }

    @Test func inclusiveDaysCoverWholeDaysEvenWhenReversed() {
        let calendar = Fixtures.calendar()
        let early = Fixtures.at("2025-10-01T15:00:00-04:00")
        let late = Fixtures.at("2025-10-31T09:00:00-04:00")
        let expected = DateInterval(
            start: Fixtures.at("2025-10-01T00:00:00-04:00"),
            end: Fixtures.at("2025-11-01T00:00:00-04:00")
        )
        #expect(calendar.inclusiveDays(from: early, through: late) == expected)
        #expect(calendar.inclusiveDays(from: late, through: early) == expected)
    }
}
