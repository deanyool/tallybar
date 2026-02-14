import Foundation

/// How entries are grouped into invoice lines.
public enum InvoiceGrouping: String, Hashable, Codable, Sendable, CaseIterable {
    /// One line per day, the usual choice.
    case day
    /// One line per entry, with its note, for clients who want the detail.
    case entry
    /// A single line for the whole period.
    case total
}

public struct InvoiceLine: Hashable, Sendable {
    public var date: Date?
    public var description: String
    /// Billable time after rounding. Amounts are computed from this, not from `hours`.
    public var billableSeconds: Int
    public var rate: Money
    public var amount: Money

    /// Hours shown on the line, to two places.
    public var hours: String {
        DurationFormat.decimalHours(billableSeconds)
    }
}

/// Everything printed on an invoice, already calculated, so the PDF renderer has no
/// money logic of its own.
public struct Invoice: Hashable, Sendable {
    public var number: String
    public var issueDate: Date
    public var dueDate: Date
    public var period: DateInterval
    public var sender: BusinessProfile
    public var client: Client
    public var lines: [InvoiceLine]
    public var taxPercent: Decimal
    public var notes: String
    /// Entries covered, so they can be marked as billed once the PDF is saved.
    public var entryIDs: Set<UUID>

    public var currency: String { client.hourlyRate.currency }

    /// Sum of the rounded line amounts, so the printed column always adds up.
    public var subtotal: Money {
        lines.reduce(.zero(currency)) { $0 + $1.amount }
    }

    public var tax: Money {
        Money(subtotal.amount * taxPercent / 100, currency: currency)
    }

    public var total: Money {
        subtotal + tax
    }

    public var billableSeconds: Int {
        lines.reduce(0) { $0 + $1.billableSeconds }
    }
}
