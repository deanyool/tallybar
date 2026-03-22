import Foundation

public extension Ledger {
    /// The number the next invoice will get, such as "INV-0007".
    var suggestedInvoiceNumber: String {
        settings.invoicePrefix + String(format: "%04d", nextInvoiceNumber)
    }

    /// Marks everything on `invoice` as billed and advances the counter. An entry that
    /// runs past the edge of the invoice period is split at that edge first, so the
    /// part that was not billed stays unbilled and can go on the next invoice.
    mutating func markInvoiced(_ invoice: Invoice) {
        var updated: [TimeEntry] = []
        for entry in entries {
            guard invoice.entryIDs.contains(entry.id),
                  let billed = entry.clipped(to: invoice.period) else {
                updated.append(entry)
                continue
            }
            var stamped = billed
            stamped.invoiceNumber = invoice.number
            updated.append(stamped)
            if entry.start < billed.start {
                updated.append(remainder(of: entry, from: entry.start, to: billed.start))
            }
            if billed.end < entry.end {
                updated.append(remainder(of: entry, from: billed.end, to: entry.end))
            }
        }
        entries = updated
        nextInvoiceNumber += 1
    }

    private func remainder(of entry: TimeEntry, from start: Date, to end: Date) -> TimeEntry {
        TimeEntry(clientID: entry.clientID, start: start, end: end, note: entry.note)
    }
}
