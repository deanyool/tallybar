import Foundation

/// The quick ranges offered on the timesheet, invoice and export screens.
public enum PeriodChoice: String, CaseIterable, Identifiable, Sendable {
    case thisWeek = "This Week"
    case lastWeek = "Last Week"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"

    public var id: String { rawValue }

    public func interval(at now: Date, calendar: Calendar) -> DateInterval {
        switch self {
        case .thisWeek:
            return calendar.weekInterval(containing: now)
        case .lastWeek:
            return calendar.weekInterval(containing: calendar.weekInterval(containing: now).start.addingTimeInterval(-1))
        case .thisMonth:
            return calendar.monthInterval(containing: now)
        case .lastMonth:
            return calendar.monthInterval(containing: calendar.monthInterval(containing: now).start.addingTimeInterval(-1))
        }
    }
}
