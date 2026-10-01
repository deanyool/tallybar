import Foundation
import Testing
import TallyCore
@testable import TallyUI

@MainActor
@Suite("App model")
struct AppModelTests {
    private let t0 = Date(timeIntervalSince1970: 1_760_000_000)

    private func directory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "tallybar-ui-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeModel(store: LedgerStore? = nil) -> (AppModel, Client) {
        var ledger = Ledger()
        ledger.settings.minimumEntrySeconds = 0
        ledger.settings.idleThresholdMinutes = 5
        let client = ledger.addClient(name: "Acme Test Co", hourlyRate: 100)
        return (AppModel(ledger: ledger, store: store, now: t0, timeZone: .gmt, locale: Locale(identifier: "en_US")), client)
    }

    @Test func oneClickStartsAndASecondClickStops() {
        let (model, client) = makeModel()
        model.toggle(clientID: client.id, at: t0)
        #expect(model.runningClient?.id == client.id)
        model.toggle(clientID: client.id, at: t0.addingTimeInterval(120))
        #expect(model.runningClient == nil)
        #expect(model.ledger.entries.count == 1)
    }

    @Test func clickingAnotherClientSwitches() {
        let (model, client) = makeModel()
        var other: Client?
        model.update { other = $0.addClient(name: "Other", hourlyRate: 1) }
        model.toggle(clientID: client.id, at: t0)
        model.toggle(clientID: other?.id ?? UUID(), at: t0.addingTimeInterval(60))
        #expect(model.runningClient?.name == "Other")
        #expect(model.ledger.entries.count == 1)
    }

    @Test func everyChangeIsSaved() throws {
        let store = LedgerStore(url: directory().appending(path: "ledger.json"))
        let (model, client) = makeModel(store: store)
        model.toggle(clientID: client.id, at: t0)
        #expect(try store.load().ledger.running?.clientID == client.id)
    }

    @Test func aFailedSaveIsReportedNotSwallowed() throws {
        let blocker = directory().appending(path: "file")
        try Data().write(to: blocker)
        let (model, client) = makeModel(store: LedgerStore(url: blocker.appending(path: "ledger.json")))
        model.toggle(clientID: client.id, at: t0)
        #expect(model.problem?.hasPrefix("Could not save") == true)
    }

    @Test func idleReturnRaisesThePromptOnce() throws {
        let (model, client) = makeModel()
        model.toggle(clientID: client.id, at: t0)
        model.tick(now: t0.addingTimeInterval(400), idleSeconds: 395)
        #expect(model.pendingAway == nil)
        model.tick(now: t0.addingTimeInterval(1000), idleSeconds: 2)
        let away = try #require(model.pendingAway)
        #expect(away.seconds >= 900)
        model.tick(now: t0.addingTimeInterval(1015), idleSeconds: 1)
        #expect(model.pendingAway == away)
    }

    @Test func discardingTheAnswerTrimsTheSession() throws {
        let (model, client) = makeModel()
        model.toggle(clientID: client.id, at: t0)
        model.tick(now: t0.addingTimeInterval(600), idleSeconds: 500)
        model.tick(now: t0.addingTimeInterval(1000), idleSeconds: 1)
        model.answerAway(.discard, at: t0.addingTimeInterval(1010))
        #expect(model.pendingAway == nil)
        #expect(model.ledger.entries.first?.seconds == 100)
        #expect(model.ledger.running?.start == t0.addingTimeInterval(1010))
    }

    @Test func noPromptWhileNotTracking() {
        let (model, _) = makeModel()
        model.tick(now: t0.addingTimeInterval(1000), idleSeconds: 900)
        model.tick(now: t0.addingTimeInterval(1015), idleSeconds: 1)
        #expect(model.pendingAway == nil)
    }

    @Test func stoppingByHandWhileAwayDoesNotPrompt() {
        let (model, client) = makeModel()
        model.toggle(clientID: client.id, at: t0)
        model.tick(now: t0.addingTimeInterval(400), idleSeconds: 390)
        model.toggle(clientID: client.id, at: t0.addingTimeInterval(410))
        model.tick(now: t0.addingTimeInterval(425), idleSeconds: 1)
        #expect(model.pendingAway == nil)
    }

    @Test func stoppingWhileThePromptIsOpenClosesItAndKeepsTheTime() {
        let (model, client) = makeModel()
        model.toggle(clientID: client.id, at: t0)
        model.tick(now: t0.addingTimeInterval(600), idleSeconds: 500)
        model.tick(now: t0.addingTimeInterval(1000), idleSeconds: 1)
        #expect(model.pendingAway != nil)
        model.toggle(at: t0.addingTimeInterval(1020))
        #expect(model.pendingAway == nil)
        #expect(model.ledger.entries.first?.seconds == 1020)
    }

    @Test func heartbeatAdvancesWhileWorking() throws {
        let (model, client) = makeModel()
        model.toggle(clientID: client.id, at: t0)
        model.tick(now: t0.addingTimeInterval(30), idleSeconds: 1)
        #expect(model.ledger.lastHeartbeat == t0)
        model.tick(now: t0.addingTimeInterval(61), idleSeconds: 1)
        #expect(model.ledger.lastHeartbeat == t0.addingTimeInterval(61))
    }

    @Test func heartbeatStopsWhileAwaySoACrashLosesNothing() {
        let (model, client) = makeModel()
        model.toggle(clientID: client.id, at: t0)
        model.tick(now: t0.addingTimeInterval(400), idleSeconds: 390)
        #expect(model.ledger.lastHeartbeat == t0)
    }

    @Test func launchRecoversASessionFromBeforeACrash() throws {
        let store = LedgerStore(url: directory().appending(path: "ledger.json"))
        let (model, client) = makeModel(store: store)
        model.toggle(clientID: client.id, at: t0)

        let relaunched = AppModel.launch(store: store, now: t0.addingTimeInterval(7200))
        #expect(relaunched.runningClient?.id == client.id)
        #expect(relaunched.pendingAway == AwayPeriod(start: t0, end: t0.addingTimeInterval(7200)))
    }

    @Test func launchReportsARecoveredFile() throws {
        let store = LedgerStore(url: directory().appending(path: "ledger.json"))
        try Data("garbage".utf8).write(to: store.url)
        let model = AppModel.launch(store: store, now: t0)
        #expect(model.problem?.contains("could not be read") == true)
    }

    @Test func launchRefusesToWriteOverAFileFromTheFuture() throws {
        let store = LedgerStore(url: directory().appending(path: "ledger.json"))
        var future = Ledger()
        future.version = Ledger.currentVersion + 1
        try store.save(future)
        let before = try Data(contentsOf: store.url)

        let model = AppModel.launch(store: store, now: t0)
        model.update { $0.addClient(name: "Would be lost", hourlyRate: 1) }
        #expect(model.problem != nil)
        #expect(try Data(contentsOf: store.url) == before)
    }

    @Test func invoiceSavesAPDFThenMarksEntries() throws {
        let (model, client) = makeModel()
        model.toggle(clientID: client.id, at: t0)
        model.toggle(clientID: client.id, at: t0.addingTimeInterval(3600))
        let url = directory().appending(path: "invoice.pdf")
        let request = InvoiceRequest(
            clientID: client.id,
            period: DateInterval(start: t0.addingTimeInterval(-86_400), end: t0.addingTimeInterval(86_400)),
            number: model.ledger.suggestedInvoiceNumber,
            issueDate: t0
        )
        try model.saveInvoice(request, to: url)
        #expect(try Data(contentsOf: url).starts(with: Data("%PDF".utf8)))
        #expect(model.ledger.entries[0].invoiceNumber == "INV-0001")
        #expect(model.ledger.suggestedInvoiceNumber == "INV-0002")
    }

    @Test func aFailedInvoiceWriteBillsNothing() {
        let (model, client) = makeModel()
        model.toggle(clientID: client.id, at: t0)
        model.toggle(clientID: client.id, at: t0.addingTimeInterval(3600))
        let request = InvoiceRequest(
            clientID: client.id,
            period: DateInterval(start: t0.addingTimeInterval(-86_400), end: t0.addingTimeInterval(86_400)),
            number: "INV-0001",
            issueDate: t0
        )
        #expect(throws: (any Error).self) {
            try model.saveInvoice(request, to: URL(filePath: "/nonexistent-directory/invoice.pdf"))
        }
        #expect(model.ledger.entries[0].invoiceNumber == nil)
        #expect(model.ledger.nextInvoiceNumber == 1)
    }

    @Test func csvIsWrittenToDisk() throws {
        let (model, client) = makeModel()
        model.toggle(clientID: client.id, at: t0)
        model.toggle(clientID: client.id, at: t0.addingTimeInterval(3600))
        let url = directory().appending(path: "export.csv")
        let interval = DateInterval(start: t0.addingTimeInterval(-86_400), end: t0.addingTimeInterval(86_400))
        try model.saveCSV(in: interval, clientID: nil, options: CSVOptions(), to: url)
        #expect(try String(decoding: Data(contentsOf: url), as: UTF8.self).contains("Acme Test Co"))
    }

    @Test func mixedCurrenciesReadAsASum() {
        let (model, _) = makeModel()
        let text = model.text(for: [Money(10, currency: "USD"), Money(5, currency: "USD")])
        #expect(text == "$10.00 + $5.00")
    }

    @Test func settingsBindingWritesThrough() {
        let (model, _) = makeModel()
        model.binding(\.weeklyGoalHours).wrappedValue = 12
        #expect(model.ledger.settings.weeklyGoalHours == 12)
        #expect(model.binding(\.weeklyGoalHours).wrappedValue == 12)
    }
}

@Suite("Period choices")
struct PeriodChoiceTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto") ?? .gmt
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text) ?? .distantPast
    }

    private let now = ISO8601DateFormatter().date(from: "2025-11-05T12:00:00-05:00") ?? .distantPast

    @Test func lastWeekEndsWhereThisWeekStarts() {
        let this = PeriodChoice.thisWeek.interval(at: now, calendar: calendar)
        let last = PeriodChoice.lastWeek.interval(at: now, calendar: calendar)
        #expect(last.end == this.start)
    }

    @Test func lastMonthCoversAllOfOctober() {
        let last = PeriodChoice.lastMonth.interval(at: now, calendar: calendar)
        #expect(last.start == date("2025-10-01T00:00:00-04:00"))
        #expect(last.end == date("2025-11-01T00:00:00-04:00"))
    }

    @Test func lastWeekAcrossYearEnd() {
        let january = date("2026-01-02T12:00:00-05:00")
        let last = PeriodChoice.lastWeek.interval(at: january, calendar: calendar)
        #expect(last.start == date("2025-12-22T00:00:00-05:00"))
    }
}
