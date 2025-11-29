import Foundation

/// The part of a time span that falls on one calendar day.
public struct DaySlice: Hashable, Sendable {
    public var day: Date
    public var start: Date
    public var end: Date

    public var seconds: Int {
        Int(end.timeIntervalSince(start))
    }
}

public extension Calendar {
    /// Splits a span at midnight.
    func daySlices(from start: Date, to end: Date) -> [DaySlice] {
        var slices: [DaySlice] = []
        var cursor = start
        while cursor < end {
            let day = dayInterval(containing: cursor)
            let sliceEnd = Swift.min(day.end, end)
            slices.append(DaySlice(day: day.start, start: cursor, end: sliceEnd))
            cursor = sliceEnd
        }
        return slices
    }

    /// The local day containing `date`.
    func dayInterval(containing date: Date) -> DateInterval {
        DateInterval(start: startOfDay(for: date), duration: 86_400)
    }

    /// The week containing `date`, honoring `firstWeekday`.
    func weekInterval(containing date: Date) -> DateInterval {
        dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 7 * 86_400)
    }
}
