import Foundation
import TallyCore
import UniformTypeIdentifiers

/// Why the New Invoice form cannot be saved yet, before the ledger is even asked.
public enum InvoiceDraftProblem: Error, Equatable, CustomStringConvertible {
    case noClient
    case missingNumber
    case endBeforeStart
    case negativeTax

    public var description: String {
        switch self {
        case .noClient: return "Choose a client."
        case .missingNumber: return "Give the invoice a number."
        case .endBeforeStart: return "The last day is before the first day."
        case .negativeTax: return "Tax can't be negative."
        }
    }
}

/// Everything the windows do, as plain methods. The views only collect input and show
/// results, so each of these runs in a test without a window or a save panel.
public extension AppModel {
    // MARK: Menu panel

    /// The line under the week total: "Today 3:15 · $390.00".
    var todayLine: String {
        let earned = text(for: todayEarnings)
        let time = "Today \(DurationFormat.clock(todaySeconds))"
        return earned.isEmpty ? time : "\(time) · \(earned)"
    }

    var summaryAccessibilityLabel: String {
        "\(DurationFormat.words(weekSeconds)) this week, \(DurationFormat.words(todaySeconds)) today"
    }

    func rateText(for client: Client) -> String {
        "\(text(for: client.hourlyRate))/h"
    }

    // MARK: Clients

    /// True when `name` would make a usable client.
    func canAddClient(name: String, hourlyRate: Decimal) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hourlyRate >= 0
    }

    /// Adds a client from the Settings form. Returns nil when the input is not usable.
    @discardableResult
    func addClient(name: String, hourlyRate: Decimal) -> Client? {
        guard canAddClient(name: name, hourlyRate: hourlyRate) else { return nil }
        var added: Client?
        update { added = $0.addClient(name: name, hourlyRate: hourlyRate) }
        return added
    }

    /// Edits one client. Currency codes are stored upper case, and a negative rate is
    /// ignored rather than saved.
    func editClient(id: UUID, _ change: (inout Client) -> Void) {
        guard var client = ledger.client(id: id) else { return }
        change(&client)
        client.hourlyRate.currency = client.hourlyRate.currency
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard client.hourlyRate.amount >= 0 else { return }
        update { $0.updateClient(client) }
    }

    func archiveClient(id: UUID, at now: Date = Date()) {
        update { $0.archiveClient(id: id, at: now) }
    }

    func restoreClient(id: UUID) {
        update { $0.unarchiveClient(id: id) }
    }

    var archivedClients: [Client] {
        ledger.clients.filter(\.isArchived)
    }

    // MARK: Timesheet

    /// A one hour entry ending now, for the Add Entry sheet.
    func newEntry(clientID: UUID?) -> TimeEntry? {
        guard let client = clientID ?? ledger.activeClients.first?.id else { return nil }
        let end = now.wholeSecond
        return TimeEntry(clientID: client, start: end.addingTimeInterval(-3600), end: end)
    }

    /// Saves a new or edited entry. Returns the reason when it was refused.
    func saveEntry(_ entry: TimeEntry) -> String? {
        do {
            try update { try $0.save(entry) }
            return nil
        } catch {
            return String(describing: error)
        }
    }

    /// Deletes an entry. Returns the reason when it was refused.
    func deleteEntry(id: UUID) -> String? {
        do {
            try update { try $0.deleteEntry(id: id) }
            return nil
        } catch {
            return String(describing: error)
        }
    }

    // MARK: Export

    func exportCSV(_ draft: ExportDraft, choose: ChooseSaveURL) -> SaveOutcome {
        guard let url = choose(draft.suggestedFileName, .commaSeparatedText) else { return .cancelled }
        do {
            let interval = draft.period.interval(at: now, calendar: calendar)
            try saveCSV(in: interval, clientID: draft.clientID, options: draft.options, to: url)
            return .saved(url)
        } catch {
            return .failed("Could not save the CSV: \(error.localizedDescription)")
        }
    }

    // MARK: Invoice

    /// A fresh form: last month, the first active client, the next number.
    func newInvoiceDraft() -> InvoiceDraft {
        var draft = InvoiceDraft(
            clientID: ledger.activeClients.first?.id,
            start: now,
            end: now,
            number: ledger.suggestedInvoiceNumber,
            taxPercent: ledger.settings.defaultTaxPercent
        )
        draft.apply(.lastMonth, at: now, calendar: calendar)
        return draft
    }

    /// The invoice the form would make right now, or why it can't.
    func invoicePreview(_ draft: InvoiceDraft) -> Result<Invoice, Error> {
        Result { try ledger.buildInvoice(validatedRequest(draft), calendar: calendar) }
    }

    /// File name for the save panel. Slashes and colons are not allowed in a file name.
    func invoiceFileName(_ draft: InvoiceDraft) -> String {
        let number = draft.number.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = number.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        return "\(safe.isEmpty ? "invoice" : safe).pdf"
    }

    /// Asks where to save, writes the PDF, marks the time as billed and moves the form
    /// on to the next number. `open` is called with the saved file.
    func saveInvoice(_ draft: inout InvoiceDraft, choose: ChooseSaveURL, open: (URL) -> Void = { _ in }) -> SaveOutcome {
        let request: InvoiceRequest
        do {
            request = try validatedRequest(draft)
            _ = try ledger.buildInvoice(request, calendar: calendar)
        } catch {
            return .failed(String(describing: error))
        }
        guard let url = choose(invoiceFileName(draft), .pdf) else { return .cancelled }
        do {
            try saveInvoice(request, to: url)
        } catch {
            return .failed("Could not save the invoice: \(error.localizedDescription)")
        }
        draft.number = ledger.suggestedInvoiceNumber
        open(url)
        return .saved(url)
    }

    private func validatedRequest(_ draft: InvoiceDraft) throws -> InvoiceRequest {
        guard let request = draft.request(issueDate: now, calendar: calendar) else {
            throw InvoiceDraftProblem.noClient
        }
        guard !request.number.isEmpty else { throw InvoiceDraftProblem.missingNumber }
        guard calendar.startOfDay(for: draft.end) >= calendar.startOfDay(for: draft.start) else {
            throw InvoiceDraftProblem.endBeforeStart
        }
        guard request.taxPercent >= 0 else { throw InvoiceDraftProblem.negativeTax }
        return request
    }

    // MARK: Hotkey

    /// Called after trying to register the shortcut with the system.
    func hotKeyRegistration(_ combo: HotKeyCombo, succeeded: Bool) {
        guard !succeeded else { return }
        problem = "\(combo.displayString) is already in use. Pick another shortcut in Settings."
    }
}
