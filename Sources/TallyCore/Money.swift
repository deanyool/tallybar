import Foundation

/// An amount of a specific currency. Always `Decimal`, never `Double`, so that
/// $0.10 + $0.20 is exactly $0.30.
public struct Money: Hashable, Sendable {
    public var amount: Decimal
    public var currency: String

    public init(_ amount: Decimal, currency: String = "USD") {
        self.amount = amount
        self.currency = currency.uppercased()
    }

    public static func zero(_ currency: String) -> Money {
        Money(0, currency: currency)
    }

    /// Fraction digits used by the currency: 2 for USD, 0 for JPY, 3 for KWD.
    public static func minorUnits(for currency: String) -> Int {
        switch currency.uppercased() {
        case "BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW", "PYG", "RWF",
             "UGX", "VND", "VUV", "XAF", "XOF", "XPF":
            return 0
        case "BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND":
            return 3
        default:
            return 2
        }
    }

    /// The same amount rounded half-up to the currency's minor unit.
    public var rounded: Money {
        Money(amount.rounded(toPlaces: Money.minorUnits(for: currency)), currency: currency)
    }

    /// What `seconds` of work earns at this hourly rate, rounded to the minor unit.
    /// Multiplies before dividing so a rate like 100/hour for 1200s stays exact.
    public func earned(seconds: Int) -> Money {
        Money(amount * Decimal(seconds) / 3600, currency: currency).rounded
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

/// Stored as a string: JSON numbers pass through `Double` and lose cents on large amounts.
/// Files written by versions before 0.4 hold a number, so decoding accepts both.
extension Money: Codable {
    private enum CodingKeys: String, CodingKey {
        case amount, currency
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let currency = try container.decode(String.self, forKey: .currency)
        if let text = try? container.decode(String.self, forKey: .amount) {
            guard let amount = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .amount, in: container, debugDescription: "not a number: \(text)"
                )
            }
            self.init(amount, currency: currency)
        } else {
            self.init(try container.decode(Decimal.self, forKey: .amount), currency: currency)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(amount.description, forKey: .amount)
        try container.encode(currency, forKey: .currency)
    }
}
