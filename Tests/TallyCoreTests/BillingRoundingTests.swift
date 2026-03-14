import Testing
@testable import TallyCore

@Suite("Billing rounding")
struct BillingRoundingTests {
    @Test(arguments: [(0, 0), (1, 1), (61, 61), (3599, 3599)])
    func zeroIncrementBillsExactTime(seconds: Int, expected: Int) {
        #expect(BillingRounding().billable(seconds: seconds) == expected)
    }

    @Test(arguments: [(1, 900), (899, 900), (900, 900), (901, 1800), (0, 0)])
    func roundsUp(seconds: Int, expected: Int) {
        #expect(BillingRounding(incrementMinutes: 15, mode: .up).billable(seconds: seconds) == expected)
    }

    @Test(arguments: [(449, 0), (450, 900), (1349, 900), (1350, 1800)])
    func roundsToNearest(seconds: Int, expected: Int) {
        #expect(BillingRounding(incrementMinutes: 15, mode: .nearest).billable(seconds: seconds) == expected)
    }

    @Test func sixMinuteIncrementsAreTenthsOfAnHour() {
        #expect(BillingRounding(incrementMinutes: 6, mode: .up).billable(seconds: 361) == 720)
    }
}
