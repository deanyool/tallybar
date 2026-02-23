import Foundation

public extension Ledger {
    /// The number the next invoice will get, such as "INV-0007".
    var suggestedInvoiceNumber: String {
        settings.invoicePrefix + String(format: "%04d", nextInvoiceNumber)
    }

}
