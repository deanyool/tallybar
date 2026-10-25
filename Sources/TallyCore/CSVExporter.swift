import Foundation

public struct CSVOptions: Equatable, Sendable {
    /// Writes one row per local day, so a session crossing midnight is two rows and
    /// a pivot table by date adds up to the same daily totals as the app.
    public var splitAtMidnight: Bool
    /// Starts the file with a UTF-8 byte order mark, which Excel needs to read accents.
    public var excelCompatible: Bool
    /// Applies the billing rounding setting to hours and amounts.
    public var applyRounding: Bool

    public init(splitAtMidnight: Bool = true, excelCompatible: Bool = false, applyRounding: Bool = false) {
        self.splitAtMidnight = splitAtMidnight
        self.excelCompatible = excelCompatible
        self.applyRounding = applyRounding
    }
}

public extension Ledger {
    /// RFC 4180 CSV of the entries inside `interval`, oldest first. Timestamps carry
    /// their UTC offset so the repeated hour on a daylight saving night stays unambiguous.
    func csv(
        in interval: DateInterval,
        clientID: UUID? = nil,
        options: CSVOptions = CSVOptions(),
        calendar: Calendar
    ) -> String {
        let timestamps = CSVTimestamps(timeZone: calendar.timeZone)
        var rows = [CSVRow.header]
        let visible = entries
            .filter { clientID == nil || $0.clientID == clientID }
            .compactMap { $0.clipped(to: interval) }
            .sorted { $0.start < $1.start }
        for entry in visible {
            guard let client = client(id: entry.clientID) else { continue }
            let slices = options.splitAtMidnight
                ? calendar.daySlices(from: entry.start, to: entry.end).map { ($0.start, $0.end) }
                : [(entry.start, entry.end)]
            for (start, end) in slices {
                let tracked = TimeEntry(clientID: client.id, start: start, end: end).seconds
                let seconds = options.applyRounding ? settings.billingRounding.billable(seconds: tracked) : tracked
                rows.append([
                    timestamps.date(start),
                    timestamps.instant(start),
                    timestamps.instant(end),
                    DurationFormat.decimalHours(seconds),
                    DurationFormat.clock(seconds),
                    client.name,
                    entry.note,
                    client.hourlyRate.plainString,
                    client.hourlyRate.earned(seconds: seconds).plainString,
                    client.hourlyRate.currency,
                    entry.invoiceNumber ?? ""
                ])
            }
        }
        let body = rows.map { $0.map(CSVRow.field).joined(separator: ",") + "\r\n" }.joined()
        return options.excelCompatible ? "\u{FEFF}" + body : body
    }
}

enum CSVRow {
    static let header = [
        "date", "start", "end", "hours", "duration", "client", "note",
        "rate", "amount", "currency", "invoice"
    ]

    private static let formulaStarters: Set<Unicode.Scalar> = ["=", "+", "-", "@", "\t", "\r"]
    private static let needsQuotes: Set<Unicode.Scalar> = [",", "\"", "\r", "\n"]

    /// Quotes when needed. A leading =, +, - or @ would run as a formula when the file
    /// is opened in a spreadsheet, so text cells starting with one get an apostrophe.
    static func field(_ value: String) -> String {
        var text = value
        if let first = text.unicodeScalars.first, formulaStarters.contains(first), Double(text) == nil {
            text = "'" + text
        }
        // Scalars, not Characters: "\r\n" is a single Character, so a search for "\n" misses it.
        guard text.unicodeScalars.contains(where: needsQuotes.contains) else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

private struct CSVTimestamps {
    private let instantFormat: Date.ISO8601FormatStyle
    private let dateFormat: Date.ISO8601FormatStyle

    init(timeZone: TimeZone) {
        instantFormat = Date.ISO8601FormatStyle(timeZone: timeZone)
            .year().month().day().time(includingFractionalSeconds: false).timeZone(separator: .colon)
        dateFormat = Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day()
    }

    func instant(_ date: Date) -> String { instantFormat.format(date) }
    func date(_ date: Date) -> String { dateFormat.format(date) }
}
