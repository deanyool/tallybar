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

}
