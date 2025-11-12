import Foundation
import Testing
@testable import TallyCore

@Suite("Money")
struct MoneyTests {
    @Test func sumsExactlyWhereDoubleWouldNot() {
        let total = Money(Decimal(string: "0.10")!) + Money(Decimal(string: "0.20")!)
        #expect(total.amount == Decimal(string: "0.30")!)
    }

    @Test(arguments: [
        ("2.345", 2, "2.35"),
        ("2.344", 2, "2.34"),
        ("2.5", 0, "3"),
        ("-2.345", 2, "-2.35"),
        ("1.10", 2, "1.1")
    ])
    func roundsHalfUp(input: String, places: Int, expected: String) {
        let value = Decimal(string: input)!
        #expect(value.rounded(toPlaces: places) == Decimal(string: expected)!)
    }

    @Test(arguments: [
        ("125.5", 2, "125.50"),
        ("0", 2, "0.00"),
        ("1250", 2, "1250.00"),
        ("0.125", 3, "0.125"),
        ("7", 0, "7"),
        ("-3.1", 2, "-3.10")
    ])
    func fixedStrings(input: String, places: Int, expected: String) {
        #expect(Decimal(string: input)!.fixedString(places: places) == expected)
    }

    @Test func earnedUsesExactSeconds() {
        // 20 minutes at 100/h is 33.33, not 0.33h * 100 = 33.00.
        #expect(Money(100).earned(seconds: 1200).amount == Decimal(string: "33.33")!)
    }

    @Test func earnedHasNoBinaryFloatDrift() {
        // 37.5 hours at 133.33/h in seconds: exactly 4999.875 before rounding.
        #expect(Money(Decimal(string: "133.33")!).earned(seconds: 135_000).amount == Decimal(string: "4999.88")!)
    }

    @Test func formatsForTheGivenLocale() {
        #expect(Money(Decimal(string: "1250.5")!).formatted(locale: Locale(identifier: "en_US")) == "$1,250.50")
    }

    @Test func normalizesCurrencyCase() {
        #expect(Money(1, currency: "eur").currency == "EUR")
    }
}
