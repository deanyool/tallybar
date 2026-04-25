import Foundation

/// The ways a duration is shown. All take whole seconds so no float drift can appear.
public enum DurationFormat {
    /// "7:05": hours and minutes, the menu bar format.
    public static func clock(_ seconds: Int) -> String {
        let total = max(0, seconds)
        return String(format: "%d:%02d", total / 3600, total % 3600 / 60)
    }

    /// "7:05:09": for the running session.
    public static func clockWithSeconds(_ seconds: Int) -> String {
        let total = max(0, seconds)
        return String(format: "%d:%02d:%02d", total / 3600, total % 3600 / 60, total % 60)
    }

    /// "7h 5m" for prompts and accessibility labels. Under a minute reads "under 1m".
    public static func words(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = total % 3600 / 60
        switch (hours, minutes) {
        case (0, 0): return "under 1m"
        case (0, _): return "\(minutes)m"
        case (_, 0): return "\(hours)h"
        default: return "\(hours)h \(minutes)m"
        }
    }

    /// Hours as an exact decimal: 5400 becomes 1.5.
    public static func hours(_ seconds: Int) -> Decimal {
        Decimal(seconds) / 3600
    }

    /// "1.50": hours to two places, for invoices and CSV.
    public static func decimalHours(_ seconds: Int) -> String {
        hours(seconds).fixedString(places: 2)
    }
}
