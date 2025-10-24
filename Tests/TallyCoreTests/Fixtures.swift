import Foundation
@testable import TallyCore

enum Fixtures {
    static func zone(_ identifier: String) -> TimeZone {
        guard let zone = TimeZone(identifier: identifier) else {
            fatalError("unknown time zone \(identifier)")
        }
        return zone
    }

    static let toronto = zone("America/Toronto")

    static func calendar(_ timeZone: TimeZone = toronto, firstWeekday: Int = 2) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    /// Parses a timestamp with an explicit offset, such as "2025-11-02T01:30:00-04:00".
    /// The offset makes the instant unambiguous even during a repeated hour.
    static func at(_ text: String) -> Date {
        guard let date = ISO8601DateFormatter().date(from: text) else {
            fatalError("bad timestamp \(text)")
        }
        return date
    }

    static func ledger(rate: Decimal = 100, currency: String = "USD") -> (Ledger, Client) {
        var ledger = Ledger()
        ledger.settings.minimumEntrySeconds = 0
        let client = ledger.addClient(name: "Acme Test Co", hourlyRate: rate, currency: currency)
        return (ledger, client)
    }

    static func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "tallybar-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
