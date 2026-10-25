import Foundation
import Testing
import TallyCore
import UniformTypeIdentifiers
@testable import TallyUI

/// The flows behind the panel and windows, driven the way the views drive them but
/// with a fake save panel and fixed clocks.
@MainActor
@Suite("Window actions")
struct ActionTests {
    /// 2025-10-09 08:53:20 UTC.
    private let t0 = Date(timeIntervalSince1970: 1_760_000_000)

    private func directory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "tallybar-action-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeModel(clients: [String] = ["Acme Test Co"]) -> AppModel {
        var ledger = Ledger()
        ledger.settings.minimumEntrySeconds = 0
        ledger.settings.idleThresholdMinutes = 5
        for name in clients {
            ledger.addClient(name: name, hourlyRate: 100, currency: "USD")
        }
        return AppModel(ledger: ledger, store: nil, now: t0, timeZone: .gmt, locale: Locale(identifier: "en_US"))
    }

    private func client(_ model: AppModel, _ index: Int = 0) -> Client {
        model.ledger.clients[index]
    }

    /// Tracks one hour for the first client, ending at t0.
    private func trackOneHour(_ model: AppModel) {
        model.toggle(clientID: client(model).id, at: t0.addingTimeInterval(-3600))
        model.toggle(clientID: client(model).id, at: t0)
    }

    /// A save panel stand-in that records what it was asked and answers with `url`.
    @MainActor
    private final class FakePanel {
        var asked: [(String, UTType)] = []
        let url: URL?
        init(url: URL?) { self.url = url }

        func choose(_ name: String, _ type: UTType) -> URL? {
            asked.append((name, type))
            return url
        }
    }

    // MARK: Menu panel

    @Test func todayLineShowsTimeAndEarnings() {
        let model = makeModel()
        #expect(model.todayLine == "Today 0:00")
        trackOneHour(model)
        #expect(model.todayLine == "Today 1:00 · $100.00")
        #expect(model.summaryAccessibilityLabel == "1h this week, 1h today")
        #expect(model.rateText(for: client(model)) == "$100.00/h")
    }

    @Test func hotkeyStartsTheLastClientAndThenStops() {
        let model = makeModel(clients: ["First", "Second"])
        model.toggle(clientID: client(model, 1).id, at: t0)
        model.toggle(at: t0.addingTimeInterval(60))
        #expect(model.runningClient == nil)
        model.toggle(at: t0.addingTimeInterval(120))
        #expect(model.runningClient?.name == "Second")
    }

    @Test func runningNoteEndsUpOnTheEntry() {
        let model = makeModel()
        model.toggle(clientID: client(model).id, at: t0)
        model.setRunningNote("Logo sketches")
        model.toggle(clientID: client(model).id, at: t0.addingTimeInterval(600))
        #expect(model.ledger.entries.first?.note == "Logo sketches")
    }

    @Test func aRefusedShortcutIsExplained() {
        let model = makeModel()
        model.hotKeyRegistration(.standard, succeeded: true)
        #expect(model.problem == nil)
        model.hotKeyRegistration(.standard, succeeded: false)
        #expect(model.problem == "⌃⌥⌘T is already in use. Pick another shortcut in Settings.")
    }

    // MARK: Away time

    private func modelWithAwayPrompt() throws -> AppModel {
        let model = makeModel()
        model.toggle(clientID: client(model).id, at: t0)
        model.tick(now: t0.addingTimeInterval(600), idleSeconds: 500)
        model.tick(now: t0.addingTimeInterval(1000), idleSeconds: 1)
        _ = try #require(model.pendingAway)
        return model
    }

    @Test func keepCountsTheAwayTime() throws {
        let model = try modelWithAwayPrompt()
        model.answerAway(.keep, at: t0.addingTimeInterval(1010))
        #expect(model.pendingAway == nil)
        #expect(model.ledger.running?.start == t0)
        #expect(model.ledger.entries.isEmpty)
        model.toggle(at: t0.addingTimeInterval(1200))
        #expect(model.ledger.entries.first?.seconds == 1200)
    }

    @Test func discardAndStopEndsTheSessionWhenYouLeft() throws {
        let model = try modelWithAwayPrompt()
        model.answerAway(.discardAndStop, at: t0.addingTimeInterval(1010))
        #expect(model.ledger.running == nil)
        #expect(model.ledger.entries.map(\.seconds) == [100])
    }

    @Test func answeringWithNothingPendingChangesNothing() {
        let model = makeModel()
        model.toggle(clientID: client(model).id, at: t0)
        let before = model.ledger
        model.answerAway(.discardAndStop, at: t0.addingTimeInterval(60))
        #expect(model.ledger == before)
    }

    @Test func relaunchAfterACrashCanDiscardTheGap() throws {
        let store = LedgerStore(url: directory().appending(path: "ledger.json"))
        var ledger = Ledger()
        ledger.settings.minimumEntrySeconds = 0
        let acme = ledger.addClient(name: "Acme Test Co", hourlyRate: 100)
        ledger.start(clientID: acme.id, at: t0)
        ledger.lastHeartbeat = t0.addingTimeInterval(1200)
        try store.save(ledger)

        let model = AppModel.launch(store: store, now: t0.addingTimeInterval(7200))
        let away = try #require(model.pendingAway)
        #expect(away.start == t0.addingTimeInterval(1200))
        model.answerAway(.discardAndStop, at: t0.addingTimeInterval(7200))
        #expect(try store.load().ledger.entries.map(\.seconds) == [1200])
    }

    // MARK: Clients

    @Test func addingAClientTrimsAndRefusesBadInput() {
        let model = makeModel(clients: [])
        #expect(!model.canAddClient(name: "   ", hourlyRate: 50))
        #expect(model.addClient(name: "  ", hourlyRate: 50) == nil)
        #expect(model.addClient(name: "Negative", hourlyRate: -1) == nil)
        let added = model.addClient(name: "  Birch Studio ", hourlyRate: 85)
        #expect(added?.name == "Birch Studio")
        #expect(model.ledger.activeClients.map(\.name) == ["Birch Studio"])
    }

    @Test func editingAClientNormalizesCurrencyAndIgnoresNegativeRates() {
        let model = makeModel()
        let id = client(model).id
        model.editClient(id: id) { $0.hourlyRate.currency = " eur " }
        #expect(client(model).hourlyRate.currency == "EUR")
        model.editClient(id: id) { $0.hourlyRate.amount = -5 }
        #expect(client(model).hourlyRate.amount == 100)
        model.editClient(id: id) { $0.name = "Acme Holdings" }
        #expect(client(model).name == "Acme Holdings")
    }

    @Test func archivingStopsTheTimerAndRestoreBringsTheClientBack() {
        let model = makeModel()
        let id = client(model).id
        model.toggle(clientID: id, at: t0)
        model.archiveClient(id: id, at: t0.addingTimeInterval(300))
        #expect(model.ledger.running == nil)
        #expect(model.ledger.entries.first?.seconds == 300)
        #expect(model.archivedClients.map(\.id) == [id])
        #expect(model.ledger.activeClients.isEmpty)
        model.restoreClient(id: id)
        #expect(model.archivedClients.isEmpty)
        #expect(model.ledger.activeClients.map(\.id) == [id])
    }

    // MARK: Timesheet

    @Test func newEntryIsTheLastHourForTheChosenClient() throws {
        let model = makeModel(clients: ["First", "Second"])
        let defaultEntry = try #require(model.newEntry(clientID: nil))
        #expect(defaultEntry.clientID == client(model, 0).id)
        #expect(defaultEntry.end == t0 && defaultEntry.seconds == 3600)
        #expect(model.newEntry(clientID: client(model, 1).id)?.clientID == client(model, 1).id)
        #expect(makeModel(clients: []).newEntry(clientID: nil) == nil)
    }

    @Test func savingEntriesReportsProblemsInPlainWords() throws {
        let model = makeModel()
        var entry = try #require(model.newEntry(clientID: nil))
        #expect(model.saveEntry(entry) == nil)
        #expect(model.ledger.entries.count == 1)

        var overlapping = entry
        overlapping.id = UUID()
        #expect(model.saveEntry(overlapping) == "This overlaps another entry.")

        entry.end = entry.start
        #expect(model.saveEntry(entry) == "The end time must be after the start time.")

        entry.end = entry.start.addingTimeInterval(1800)
        entry.note = "Shortened"
        #expect(model.saveEntry(entry) == nil)
        #expect(model.ledger.entries.map(\.seconds) == [1800])
        #expect(model.ledger.entries.first?.note == "Shortened")
    }

    @Test func deletingAnEntryAndRefusingABilledOne() throws {
        let model = makeModel()
        trackOneHour(model)
        let id = try #require(model.ledger.entries.first?.id)
        #expect(model.deleteEntry(id: id) == nil)
        #expect(model.ledger.entries.isEmpty)

        trackOneHour(model)
        var draft = model.newInvoiceDraft()
        draft.apply(.thisMonth, at: t0, calendar: model.calendar)
        let panel = FakePanel(url: directory().appending(path: "invoice.pdf"))
        _ = model.saveInvoice(&draft, choose: panel.choose)
        let billed = try #require(model.ledger.entries.first)
        #expect(model.deleteEntry(id: billed.id) == "This entry was billed on invoice INV-0001.")
        #expect(model.ledger.entries.count == 1)
    }

    // MARK: Export

    @Test func exportWritesTheChosenFile() throws {
        let model = makeModel(clients: ["Acme Test Co", "Other Co"])
        trackOneHour(model)
        let url = directory().appending(path: "out.csv")
        let panel = FakePanel(url: url)
        let draft = ExportDraft(period: .thisMonth, clientID: client(model).id)

        #expect(model.exportCSV(draft, choose: panel.choose) == .saved(url))
        #expect(panel.asked.first?.0 == "tallybar-this-month.csv")
        #expect(panel.asked.first?.1 == .commaSeparatedText)
        let text = try #require(String(bytes: Data(contentsOf: url), encoding: .utf8))
        #expect(text.components(separatedBy: "\n").filter { !$0.isEmpty }.count == 2)
        #expect(text.contains("Acme Test Co"))
    }

    @Test func cancellingTheExportWritesNothing() {
        let model = makeModel()
        trackOneHour(model)
        #expect(model.exportCSV(ExportDraft(), choose: FakePanel(url: nil).choose) == .cancelled)
        #expect(SaveOutcome.cancelled.problem == nil)
    }

    @Test func aFailedExportSaysWhy() {
        let model = makeModel()
        let panel = FakePanel(url: URL(filePath: "/nonexistent-directory/out.csv"))
        let outcome = model.exportCSV(ExportDraft(period: .lastWeek), choose: panel.choose)
        #expect(outcome.problem?.hasPrefix("Could not save the CSV") == true)
        #expect(panel.asked.first?.0 == "tallybar-last-week.csv")
    }

    // MARK: Invoice

    @Test func newInvoiceDraftStartsOnLastMonth() {
        let model = makeModel()
        model.update { $0.settings.defaultTaxPercent = 13 }
        let draft = model.newInvoiceDraft()
        #expect(draft.clientID == client(model).id)
        #expect(draft.number == "INV-0001")
        #expect(draft.taxPercent == 13)
        #expect(draft.start == Date(timeIntervalSince1970: 1_756_684_800)) // 2025-09-01 UTC
        #expect(draft.matchingChoice(at: t0, calendar: model.calendar) == .lastMonth)
    }

    @Test func editingADateClearsTheQuickRange() {
        let model = makeModel()
        var draft = model.newInvoiceDraft()
        draft.apply(.thisWeek, at: t0, calendar: model.calendar)
        #expect(draft.matchingChoice(at: t0, calendar: model.calendar) == .thisWeek)
        draft.end = draft.end.addingTimeInterval(86_400 * 3)
        #expect(draft.matchingChoice(at: t0, calendar: model.calendar) == nil)
    }

    @Test func previewExplainsWhatIsMissing() {
        let model = makeModel()
        trackOneHour(model)
        var draft = model.newInvoiceDraft()
        #expect(model.invoicePreview(draft).problemText == InvoiceError.noBillableTime.description)

        draft.apply(.thisMonth, at: t0, calendar: model.calendar)
        #expect(model.invoicePreview(draft).problemText == nil)

        var noNumber = draft
        noNumber.number = "  "
        #expect(model.invoicePreview(noNumber).problemText == "Give the invoice a number.")

        var backwards = draft
        backwards.end = draft.start.addingTimeInterval(-86_400)
        #expect(model.invoicePreview(backwards).problemText == "The last day is before the first day.")

        var negativeTax = draft
        negativeTax.taxPercent = -1
        #expect(model.invoicePreview(negativeTax).problemText == "Tax can't be negative.")

        var noClient = draft
        noClient.clientID = nil
        #expect(model.invoicePreview(noClient).problemText == "Choose a client.")
    }

    @Test func savingAnInvoiceBillsOpensAndMovesToTheNextNumber() throws {
        let model = makeModel()
        trackOneHour(model)
        var draft = model.newInvoiceDraft()
        draft.apply(.thisMonth, at: t0, calendar: model.calendar)
        let url = directory().appending(path: "INV-0001.pdf")
        let panel = FakePanel(url: url)
        var opened: [URL] = []

        let outcome = model.saveInvoice(&draft, choose: panel.choose) { opened.append($0) }

        #expect(outcome == .saved(url))
        #expect(panel.asked.first?.0 == "INV-0001.pdf")
        #expect(panel.asked.first?.1 == .pdf)
        #expect(opened == [url])
        #expect(try Data(contentsOf: url).starts(with: Data("%PDF".utf8)))
        #expect(model.ledger.entries.allSatisfy { $0.invoiceNumber == "INV-0001" })
        #expect(draft.number == "INV-0002")

        let again = model.saveInvoice(&draft, choose: panel.choose)
        #expect(again == .failed(InvoiceError.noBillableTime.description))
        #expect(panel.asked.count == 1)
    }

    @Test func cancellingTheInvoiceBillsNothing() {
        let model = makeModel()
        trackOneHour(model)
        var draft = model.newInvoiceDraft()
        draft.apply(.thisMonth, at: t0, calendar: model.calendar)
        var opened = false
        #expect(model.saveInvoice(&draft, choose: FakePanel(url: nil).choose) { _ in opened = true } == .cancelled)
        #expect(!opened)
        #expect(draft.number == "INV-0001")
        #expect(model.ledger.entries.allSatisfy { $0.invoiceNumber == nil })
    }

    @Test func aFailedInvoiceWriteKeepsTheFormAndBillsNothing() {
        let model = makeModel()
        trackOneHour(model)
        var draft = model.newInvoiceDraft()
        draft.apply(.thisMonth, at: t0, calendar: model.calendar)
        let panel = FakePanel(url: URL(filePath: "/nonexistent-directory/x.pdf"))
        let outcome = model.saveInvoice(&draft, choose: panel.choose)
        #expect(outcome.problem?.hasPrefix("Could not save the invoice") == true)
        #expect(draft.number == "INV-0001")
        #expect(model.ledger.entries.allSatisfy { $0.invoiceNumber == nil })
    }

    @Test func invoiceFileNamesAreSafe() {
        let model = makeModel()
        var draft = model.newInvoiceDraft()
        draft.number = "2025/10:3"
        #expect(model.invoiceFileName(draft) == "2025-10-3.pdf")
        draft.number = ""
        #expect(model.invoiceFileName(draft) == "invoice.pdf")
    }
}

private extension Result where Failure == Error {
    var problemText: String? {
        if case let .failure(error) = self { return String(describing: error) }
        return nil
    }
}

/// The Launch at Login switch against a stand-in for `SMAppService`.
@Suite("Launch at login")
struct LaunchAtLoginStateTests {
    private final class FakeService: @unchecked Sendable {
        var enabled = false
        var needsApproval = false
        var failure: (any Error)?
    }

    private struct Refused: LocalizedError {
        var errorDescription: String? { "Operation not permitted" }
    }

    private func control(_ service: FakeService, available: Bool = true) -> LaunchAtLoginControl {
        LaunchAtLoginControl(
            isAvailable: available,
            isEnabled: { service.enabled },
            setEnabled: { wanted in
                if let failure = service.failure { throw failure }
                service.enabled = wanted && !service.needsApproval
            }
        )
    }

    @Test func turningOnAndOff() {
        let service = FakeService()
        var state = LaunchAtLoginState()
        state.set(true, using: control(service))
        #expect(state == LaunchAtLoginState(isOn: true, problem: nil))
        state.set(false, using: control(service))
        #expect(state == LaunchAtLoginState(isOn: false, problem: nil))
    }

    @Test func waitingForApprovalSaysWhereToLook() {
        let service = FakeService()
        service.needsApproval = true
        var state = LaunchAtLoginState()
        state.set(true, using: control(service))
        #expect(!state.isOn)
        #expect(state.problem?.contains("System Settings > General > Login Items") == true)
    }

    @Test func aFailureShowsTheRealState() {
        let service = FakeService()
        service.enabled = true
        service.failure = Refused()
        var state = LaunchAtLoginState()
        state.refresh(using: control(service))
        state.set(false, using: control(service))
        #expect(state.isOn)
        #expect(state.problem == "Could not change Launch at Login: Operation not permitted")
    }

    @Test func outsideTheAppBundleItStaysOff() {
        var state = LaunchAtLoginState()
        state.set(true, using: control(FakeService(), available: false))
        #expect(!state.isOn)
        #expect(state.problem == LaunchAtLoginState.unavailableMessage)
    }
}
