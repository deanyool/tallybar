import Foundation

public enum InvoiceError: Error, Equatable, CustomStringConvertible {
    case noBillableTime
    case unknownClient

    public var description: String {
        switch self {
        case .noBillableTime:
            return "There is no unbilled time for this client in that period."
        case .unknownClient:
            return "That client no longer exists."
        }
    }
}

/// The choices made on the New Invoice screen.
public struct InvoiceRequest: Sendable {
    public var clientID: UUID
    public var period: DateInterval
    public var number: String
    public var issueDate: Date
    public var grouping: InvoiceGrouping
    public var taxPercent: Decimal
    public var notes: String

    public init(
        clientID: UUID,
        period: DateInterval,
        number: String,
        issueDate: Date,
        grouping: InvoiceGrouping = .day,
        taxPercent: Decimal = 0,
        notes: String = ""
    ) {
        self.clientID = clientID
        self.period = period
        self.number = number
        self.issueDate = issueDate
        self.grouping = grouping
        self.taxPercent = taxPercent
        self.notes = notes
    }
}

public extension Ledger {
    /// Turns tracked time into an invoice. Time is clipped to the period and split at
    /// local midnight, so a late session lands on the right days and only the billed
    /// part counts. Each piece is priced from exact seconds.
    func buildInvoice(_ request: InvoiceRequest, calendar: Calendar) throws -> Invoice {
        guard let client = client(id: request.clientID) else { throw InvoiceError.unknownClient }
        let billable = entries
            .filter { $0.clientID == client.id }
            .compactMap { $0.clipped(to: request.period) }
            .sorted { $0.start < $1.start }
        guard !billable.isEmpty else { throw InvoiceError.noBillableTime }

        let pieces = billable.flatMap { entry in
            calendar.daySlices(from: entry.start, to: entry.end).map { slice in
                InvoicePiece(
                    day: slice.day,
                    note: entry.note,
                    seconds: slice.seconds
                )
            }
        }
        let lines = InvoicePiece.lines(from: pieces, grouping: request.grouping, client: client)
        guard lines.contains(where: { $0.billableSeconds > 0 }) else { throw InvoiceError.noBillableTime }

        let dueDate = calendar.date(byAdding: .day, value: settings.paymentTermsDays, to: request.issueDate)
        return Invoice(
            number: request.number,
            issueDate: request.issueDate,
            dueDate: dueDate ?? request.issueDate,
            period: request.period,
            sender: settings.business,
            client: client,
            lines: lines,
            taxPercent: request.taxPercent,
            notes: request.notes,
            entryIDs: Set(billable.map(\.id))
        )
    }
}

/// A fragment of work on one day, before grouping into lines.
private struct InvoicePiece {
    var day: Date
    var note: String
    var seconds: Int

    static func lines(from pieces: [InvoicePiece], grouping: InvoiceGrouping, client: Client) -> [InvoiceLine] {
        func line(date: Date?, description: String, seconds: Int) -> InvoiceLine {
            InvoiceLine(
                date: date,
                description: description,
                billableSeconds: seconds,
                rate: client.hourlyRate,
                amount: client.hourlyRate.earned(seconds: seconds)
            )
        }
        switch grouping {
        case .entry:
            return pieces.map {
                line(date: $0.day, description: $0.note.isEmpty ? "Consulting" : $0.note, seconds: $0.seconds)
            }
        case .day:
            let days = Dictionary(grouping: pieces, by: \.day)
            return days.keys.sorted().map { day in
                let group = days[day] ?? []
                return line(date: day, description: summary(of: group), seconds: group.reduce(0) { $0 + $1.seconds })
            }
        case .total:
            return [line(date: nil, description: "Professional services", seconds: pieces.reduce(0) { $0 + $1.seconds })]
        }
    }

    /// The day's distinct notes in the order they happened.
    private static func summary(of pieces: [InvoicePiece]) -> String {
        var seen: [String] = []
        for piece in pieces where !piece.note.isEmpty && !seen.contains(piece.note) {
            seen.append(piece.note)
        }
        return seen.isEmpty ? "Consulting" : seen.joined(separator: "; ")
    }
}
