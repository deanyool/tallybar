import Foundation

public extension Decimal {
    /// Rounds to `places` fraction digits. The default is half-up, the rule people expect
    /// on an invoice (2.345 becomes 2.35), rather than the banker's rounding of `.bankers`.
    func rounded(toPlaces places: Int, mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, places, mode)
        return result
    }

    /// A locale-independent string with exactly `places` fraction digits, for CSV and JSON.
    func fixedString(places: Int) -> String {
        let scaled = rounded(toPlaces: places)
        let text = scaled.description
        guard places > 0 else { return text }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        let whole = parts[0]
        let fraction = parts.count > 1 ? String(parts[1]) : ""
        return "\(whole).\(fraction.padding(toLength: places, withPad: "0", startingAt: 0))"
    }
}
