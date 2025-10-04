import Foundation

/// An amount of a specific currency. Always `Decimal`, never `Double`, so that
/// $0.10 + $0.20 is exactly $0.30.
public struct Money: Hashable, Codable, Sendable {
    public var amount: Decimal
    public var currency: String

    public init(_ amount: Decimal, currency: String = "USD") {
        self.amount = amount
        self.currency = currency.uppercased()
    }

    public static func zero(_ currency: String) -> Money {
        Money(0, currency: currency)
    }

    /// Fraction digits used by the currency.
    public static func minorUnits(for currency: String) -> Int {
        2
    }

    /// The same amount rounded half-up to the currency's minor unit.
    public var rounded: Money {
        Money(amount.rounded(toPlaces: Money.minorUnits(for: currency)), currency: currency)
    }

    /// What `seconds` of work earns at this hourly rate, rounded to the minor unit.
    public func earned(seconds: Int) -> Money {
        Money(amount / 3600 * Decimal(seconds), currency: currency).rounded
    }

    /// A display string such as "$1,250.00".
    public func formatted(locale: Locale = .current) -> String {
        amount.formatted(.currency(code: currency).locale(locale))
    }

    /// A plain amount such as "1250.00" with no currency symbol or grouping.
    public var plainString: String {
        amount.fixedString(places: Money.minorUnits(for: currency))
    }
}

extension Money: Comparable {
    public static func < (lhs: Money, rhs: Money) -> Bool {
        lhs.amount < rhs.amount
    }
}

public extension Money {
    static func + (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency, "cannot add \(lhs.currency) to \(rhs.currency)")
        return Money(lhs.amount + rhs.amount, currency: lhs.currency)
    }
}
