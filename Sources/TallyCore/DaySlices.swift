import Foundation

/// The part of a time span that falls on one calendar day.
public struct DaySlice: Hashable, Sendable {
    /// The start of the local day. Not always midnight: some zones spring forward at 00:00.
    public var day: Date
    public var start: Date
    public var end: Date

    public var seconds: Int {
        Int(end.timeIntervalSince1970.rounded()) - Int(start.timeIntervalSince1970.rounded())
    }
}

public extension Calendar {
    /// Splits a span at local day boundaries. Asking the calendar for each day's real
    /// bounds, rather than adding 86,400 seconds, is what keeps a 23 or 25 hour day
    /// correct. The slice lengths always add up to the length of the span.
    func daySlices(from start: Date, to end: Date) -> [DaySlice] {
        var slices: [DaySlice] = []
        var cursor = start
        while cursor < end, let day = dateInterval(of: .day, for: cursor) {
            let sliceEnd = Swift.min(day.end, end)
            slices.append(DaySlice(day: day.start, start: cursor, end: sliceEnd))
            cursor = sliceEnd
        }
        return slices
    }

    /// The local day containing `date`.
    func dayInterval(containing date: Date) -> DateInterval {
        dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 86_400)
    }

    /// The week containing `date`, honoring `firstWeekday`.
    func weekInterval(containing date: Date) -> DateInterval {
        dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 7 * 86_400)
    }

    /// The month containing `date`.
    func monthInterval(containing date: Date) -> DateInterval {
        dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 30 * 86_400)
    }

    /// From the start of the first day through the end of the last day, as picked in a
    /// date range control. Reversed input is put back in order.
    func inclusiveDays(from first: Date, through last: Date) -> DateInterval {
        let lower = Swift.min(first, last)
        let upper = Swift.max(first, last)
        return DateInterval(
            start: dayInterval(containing: lower).start,
            end: dayInterval(containing: upper).end
        )
    }
}
