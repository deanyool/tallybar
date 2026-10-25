import Foundation
import TallyCore
import UniformTypeIdentifiers

/// Asks the person where to save a file. The app passes one that shows a save panel;
/// tests pass one that returns a fixed URL, or nil to act like Cancel.
public typealias ChooseSaveURL = @MainActor (_ suggestedName: String, _ type: UTType) -> URL?

/// How a save from one of the windows ended.
public enum SaveOutcome: Equatable, Sendable {
    case saved(URL)
    case cancelled
    case failed(String)

    /// The text to show under the form, or nil when there is nothing to say.
    public var problem: String? {
        if case let .failed(message) = self { return message }
        return nil
    }
}

/// The choices on the Export CSV window.
public struct ExportDraft: Equatable, Sendable {
    public var period: PeriodChoice
    public var clientID: UUID?
    public var options: CSVOptions

    public init(period: PeriodChoice = .thisMonth, clientID: UUID? = nil, options: CSVOptions = CSVOptions()) {
        self.period = period
        self.clientID = clientID
        self.options = options
    }

    /// "tallybar-this-month.csv" and so on.
    public var suggestedFileName: String {
        "tallybar-\(period.rawValue.lowercased().replacingOccurrences(of: " ", with: "-")).csv"
    }
}

/// The choices on the New Invoice window. `start` and `end` are the first and last
/// days shown in the date pickers; the invoice covers both days in full.
public struct InvoiceDraft: Equatable, Sendable {
    public var clientID: UUID?
    public var start: Date
    public var end: Date
    public var number: String
    public var grouping: InvoiceGrouping
    public var taxPercent: Decimal
    public var notes: String

    public init(
        clientID: UUID?,
        start: Date,
        end: Date,
        number: String,
        grouping: InvoiceGrouping = .day,
        taxPercent: Decimal = 0,
        notes: String = ""
    ) {
        self.clientID = clientID
        self.start = start
        self.end = end
        self.number = number
        self.grouping = grouping
        self.taxPercent = taxPercent
        self.notes = notes
    }

    /// Fills both dates from a quick range.
    public mutating func apply(_ choice: PeriodChoice, at now: Date, calendar: Calendar) {
        let interval = choice.interval(at: now, calendar: calendar)
        start = interval.start
        end = interval.end.addingTimeInterval(-1)
    }

    /// The quick range the dates match, if any. Editing the dates by hand shows none.
    public func matchingChoice(at now: Date, calendar: Calendar) -> PeriodChoice? {
        PeriodChoice.allCases.first { choice in
            let interval = choice.interval(at: now, calendar: calendar)
            return calendar.isDate(interval.start, inSameDayAs: start)
                && calendar.isDate(interval.end.addingTimeInterval(-1), inSameDayAs: end)
        }
    }

    public func request(issueDate: Date, calendar: Calendar) -> InvoiceRequest? {
        guard let clientID else { return nil }
        return InvoiceRequest(
            clientID: clientID,
            period: calendar.inclusiveDays(from: start, through: end),
            number: number.trimmingCharacters(in: .whitespacesAndNewlines),
            issueDate: issueDate,
            grouping: grouping,
            taxPercent: taxPercent,
            notes: notes
        )
    }
}

/// The Launch at Login switch: what it shows and the last thing that went wrong.
public struct LaunchAtLoginState: Equatable, Sendable {
    public var isOn = false
    public var problem: String?

    public init(isOn: Bool = false, problem: String? = nil) {
        self.isOn = isOn
        self.problem = problem
    }

    /// Reads the current state from the system.
    public mutating func refresh(using control: LaunchAtLoginControl) {
        isOn = control.isEnabled()
    }

    /// Flips the switch. The switch always ends up showing what macOS reports, so it
    /// cannot claim to be on when registration failed or is waiting for approval.
    public mutating func set(_ wanted: Bool, using control: LaunchAtLoginControl) {
        guard control.isAvailable else {
            isOn = false
            problem = LaunchAtLoginState.unavailableMessage
            return
        }
        do {
            try control.setEnabled(wanted)
            isOn = control.isEnabled()
            problem = wanted && !isOn ? LaunchAtLoginState.approvalMessage : nil
        } catch {
            isOn = control.isEnabled()
            problem = "Could not change Launch at Login: \(error.localizedDescription)"
        }
    }

    static let unavailableMessage = "Available when running the built TallyBar.app."
    static let approvalMessage =
        "macOS has not allowed it yet. Turn TallyBar on in System Settings > General > Login Items."
}
