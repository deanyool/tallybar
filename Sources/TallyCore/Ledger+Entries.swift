import Foundation

/// Why a manual entry was refused.
public enum EntryProblem: Error, Equatable, Sendable {
    case endNotAfterStart
    case unknownClient
    case alreadyInvoiced(String)
}

extension EntryProblem: CustomStringConvertible {
    public var description: String {
        switch self {
        case .endNotAfterStart:
            return "The end time must be after the start time."
        case .unknownClient:
            return "That client no longer exists."
        case .alreadyInvoiced(let number):
            return "This entry was billed on invoice \(number)."
        }
    }
}

public extension Ledger {
    /// Entries sorted newest first.
    var entriesNewestFirst: [TimeEntry] {
        entries.sorted { $0.start > $1.start }
    }

    /// Checks a new or edited entry.
    func validate(_ entry: TimeEntry) throws {
        guard entry.end > entry.start else { throw EntryProblem.endNotAfterStart }
        guard client(id: entry.clientID) != nil else { throw EntryProblem.unknownClient }
        if let number = entries.first(where: { $0.id == entry.id })?.invoiceNumber {
            throw EntryProblem.alreadyInvoiced(number)
        }
    }

    /// Adds or replaces an entry after validating it.
    mutating func save(_ entry: TimeEntry) throws {
        var clean = entry
        clean.start = entry.start.wholeSecond
        clean.end = entry.end.wholeSecond
        try validate(clean)
        if let index = entries.firstIndex(where: { $0.id == clean.id }) {
            entries[index] = clean
        } else {
            entries.append(clean)
        }
    }

    /// Removes an entry. Invoiced entries stay so the invoice can always be explained.
    mutating func deleteEntry(id: UUID) throws {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        if let number = entries[index].invoiceNumber {
            throw EntryProblem.alreadyInvoiced(number)
        }
        entries.remove(at: index)
    }
}
