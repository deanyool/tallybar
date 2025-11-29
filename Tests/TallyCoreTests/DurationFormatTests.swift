import Foundation
import Testing
@testable import TallyCore

@Suite("Duration formatting")
struct DurationFormatTests {
    @Test(arguments: [(0, "0:00"), (59, "0:00"), (60, "0:01"), (3660, "1:01"), (360_000, "100:00"), (-5, "0:00")])
    func clock(seconds: Int, expected: String) {
        #expect(DurationFormat.clock(seconds) == expected)
    }

    @Test(arguments: [(0, "0:00:00"), (3725, "1:02:05"), (86_400, "24:00:00")])
    func clockWithSeconds(seconds: Int, expected: String) {
        #expect(DurationFormat.clockWithSeconds(seconds) == expected)
    }

    @Test(arguments: [(30, "under 1m"), (60, "1m"), (1380, "23m"), (3600, "1h"), (5400, "1h 30m")])
    func words(seconds: Int, expected: String) {
        #expect(DurationFormat.words(seconds) == expected)
    }

    @Test(arguments: [(5400, "1.50"), (1200, "0.33"), (0, "0.00"), (29_700, "8.25")])
    func decimalHours(seconds: Int, expected: String) {
        #expect(DurationFormat.decimalHours(seconds) == expected)
    }

    @Test func hoursAreExactDecimals() {
        #expect(DurationFormat.hours(5400) == Decimal(string: "1.5")!)
    }
}
