import Foundation

public extension Calendar {
    /// The local day containing `date`.
    func dayInterval(containing date: Date) -> DateInterval {
        DateInterval(start: startOfDay(for: date), duration: 86_400)
    }

    /// The week containing `date`, honoring `firstWeekday`.
    func weekInterval(containing date: Date) -> DateInterval {
        dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 7 * 86_400)
    }
}
