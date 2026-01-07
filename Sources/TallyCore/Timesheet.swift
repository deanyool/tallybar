import Foundation

/// One entry as it appears under one day. An entry that crosses midnight appears under
/// both days, each row showing only that day's share.
public struct TimesheetRow: Identifiable, Hashable, Sendable {
    public var entry: TimeEntry
    public var slice: DaySlice

    public var id: String { "\(entry.id)-\(slice.day.timeIntervalSince1970)" }
    public var seconds: Int { slice.seconds }
    public var continuesFromPreviousDay: Bool { slice.start > entry.start }
    public var continuesToNextDay: Bool { slice.end < entry.end }
}

public struct TimesheetDay: Identifiable, Hashable, Sendable {
    public var day: Date
    public var rows: [TimesheetRow]

    public var id: Date { day }
    public var seconds: Int { rows.reduce(0) { $0 + $1.seconds } }
}

public extension Ledger {
    /// Entries grouped by local day, newest day first, oldest row first within a day.
    func timesheet(in interval: DateInterval, clientID: UUID? = nil, calendar: Calendar) -> [TimesheetDay] {
        var days: [Date: [TimesheetRow]] = [:]
        for entry in entries where clientID == nil || entry.clientID == clientID {
            guard let visible = entry.clipped(to: interval) else { continue }
            for slice in calendar.daySlices(from: visible.start, to: visible.end) {
                days[slice.day, default: []].append(TimesheetRow(entry: entry, slice: slice))
            }
        }
        return days
            .map { day, rows in
                TimesheetDay(day: day, rows: rows.sorted { $0.slice.start < $1.slice.start })
            }
            .sorted { $0.day > $1.day }
    }
}
