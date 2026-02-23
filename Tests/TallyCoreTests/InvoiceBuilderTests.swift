import Foundation
import Testing
@testable import TallyCore

@Suite("Invoice calculation")
struct InvoiceBuilderTests {
    private let calendar = Fixtures.calendar()
    private let october = DateInterval(
        start: Fixtures.at("2025-10-01T00:00:00-04:00"),
        end: Fixtures.at("2025-11-01T00:00:00-04:00")
    )
    private let issued = Fixtures.at("2025-11-01T10:00:00-04:00")

    private func entry(_ client: Client, _ start: String, _ end: String, note: String = "") -> TimeEntry {
        TimeEntry(clientID: client.id, start: Fixtures.at(start), end: Fixtures.at(end), note: note)
    }

    private func request(_ client: Client, grouping: InvoiceGrouping = .day, tax: Decimal = 0) -> InvoiceRequest {
        InvoiceRequest(
            clientID: client.id, period: october, number: "INV-0001", issueDate: issued,
            grouping: grouping, taxPercent: tax
        )
    }

    @Test func groupsByDayWithDistinctNotes() throws {
        var (ledger, client) = Fixtures.ledger()
        ledger.entries = [
            entry(client, "2025-10-06T09:00:00-04:00", "2025-10-06T10:00:00-04:00", note: "Design"),
            entry(client, "2025-10-06T11:00:00-04:00", "2025-10-06T11:30:00-04:00", note: "Calls"),
            entry(client, "2025-10-06T12:00:00-04:00", "2025-10-06T12:30:00-04:00", note: "Design"),
            entry(client, "2025-10-07T09:00:00-04:00", "2025-10-07T10:00:00-04:00")
        ]
        let invoice = try ledger.buildInvoice(request(client), calendar: calendar)
        #expect(invoice.lines.count == 2)
        #expect(invoice.lines[0].description == "Design; Calls")
        #expect(invoice.lines[0].hours == "2.00")
        #expect(invoice.lines[1].description == "Consulting")
        #expect(invoice.subtotal.amount == 300)
    }

    @Test func midnightSessionLandsOnBothDays() throws {
        var (ledger, client) = Fixtures.ledger()
        ledger.entries = [entry(client, "2025-10-15T23:00:00-04:00", "2025-10-16T01:00:00-04:00")]
        let invoice = try ledger.buildInvoice(request(client), calendar: calendar)
        #expect(invoice.lines.map(\.billableSeconds) == [3600, 3600])
        #expect(invoice.lines.map(\.date) == [
            Fixtures.at("2025-10-15T00:00:00-04:00"),
            Fixtures.at("2025-10-16T00:00:00-04:00")
        ])
    }

    @Test func onlyTheBilledPartOfAnEdgeSessionCounts() throws {
        var (ledger, client) = Fixtures.ledger()
        ledger.entries = [entry(client, "2025-10-31T23:00:00-04:00", "2025-11-01T02:00:00-04:00")]
        let invoice = try ledger.buildInvoice(request(client), calendar: calendar)
        #expect(invoice.billableSeconds == 3600)
    }

    @Test func fallBackNightBillsTheRealHours() throws {
        let november = DateInterval(
            start: Fixtures.at("2025-11-01T00:00:00-04:00"),
            end: Fixtures.at("2025-12-01T00:00:00-05:00")
        )
        var (ledger, client) = Fixtures.ledger()
        ledger.entries = [entry(client, "2025-11-02T00:30:00-04:00", "2025-11-02T02:30:00-05:00")]
        var request = request(client)
        request.period = november
        let invoice = try ledger.buildInvoice(request, calendar: calendar)
        #expect(invoice.billableSeconds == 3 * 3600)
        #expect(invoice.subtotal.amount == 300)
    }

    @Test func taxRoundsHalfUpOnTheSubtotal() throws {
        var (ledger, client) = Fixtures.ledger(rate: Decimal(string: "33.50")!)
        ledger.entries = [entry(client, "2025-10-06T09:00:00-04:00", "2025-10-06T10:00:00-04:00")]
        let invoice = try ledger.buildInvoice(request(client, tax: 13), calendar: calendar)
        #expect(invoice.tax.amount == Decimal(string: "4.36")!)
        #expect(invoice.total.amount == Decimal(string: "37.86")!)
    }

    @Test func subtotalIsTheSumOfThePrintedLines() throws {
        var (ledger, client) = Fixtures.ledger(rate: 100)
        // 20 minutes three times: each line rounds to 33.33, and 99.99 is what must print.
        ledger.entries = [
            entry(client, "2025-10-06T09:00:00-04:00", "2025-10-06T09:20:00-04:00"),
            entry(client, "2025-10-07T09:00:00-04:00", "2025-10-07T09:20:00-04:00"),
            entry(client, "2025-10-08T09:00:00-04:00", "2025-10-08T09:20:00-04:00")
        ]
        let invoice = try ledger.buildInvoice(request(client), calendar: calendar)
        #expect(invoice.subtotal.amount == Decimal(string: "99.99")!)
    }

    @Test func perEntryGroupingKeepsNotes() throws {
        var (ledger, client) = Fixtures.ledger()
        ledger.entries = [
            entry(client, "2025-10-06T09:00:00-04:00", "2025-10-06T10:00:00-04:00", note: "A"),
            entry(client, "2025-10-06T11:00:00-04:00", "2025-10-06T12:00:00-04:00", note: "B")
        ]
        let invoice = try ledger.buildInvoice(request(client, grouping: .entry), calendar: calendar)
        #expect(invoice.lines.map(\.description) == ["A", "B"])
    }

    @Test func totalGroupingIsASingleLine() throws {
        var (ledger, client) = Fixtures.ledger()
        ledger.entries = [
            entry(client, "2025-10-06T09:00:00-04:00", "2025-10-06T10:00:00-04:00"),
            entry(client, "2025-10-20T11:00:00-04:00", "2025-10-20T12:00:00-04:00")
        ]
        let invoice = try ledger.buildInvoice(request(client, grouping: .total), calendar: calendar)
        #expect(invoice.lines.count == 1)
        #expect(invoice.lines[0].date == nil)
        #expect(invoice.subtotal.amount == 200)
    }

    @Test func dueDateFollowsTerms() throws {
        var (ledger, client) = Fixtures.ledger()
        ledger.settings.paymentTermsDays = 14
        ledger.entries = [entry(client, "2025-10-06T09:00:00-04:00", "2025-10-06T10:00:00-04:00")]
        let invoice = try ledger.buildInvoice(request(client), calendar: calendar)
        #expect(invoice.dueDate == Fixtures.at("2025-11-15T10:00:00-05:00"))
    }

    @Test func otherClientsTimeIsLeftOut() {
        var (ledger, client) = Fixtures.ledger()
        let other = ledger.addClient(name: "Other", hourlyRate: 10)
        ledger.entries = [entry(other, "2025-10-06T09:00:00-04:00", "2025-10-06T10:00:00-04:00")]
        #expect(throws: InvoiceError.noBillableTime) {
            try ledger.buildInvoice(request(client), calendar: calendar)
        }
    }

    @Test func unknownClientIsAnError() {
        let (ledger, _) = Fixtures.ledger()
        let request = InvoiceRequest(clientID: UUID(), period: october, number: "X", issueDate: issued)
        #expect(throws: InvoiceError.unknownClient) {
            try ledger.buildInvoice(request, calendar: calendar)
        }
    }

    @Test func customPrefixAppearsInTheNumber() {
        var ledger = Ledger()
        ledger.settings.invoicePrefix = "2025-"
        ledger.nextInvoiceNumber = 42
        #expect(ledger.suggestedInvoiceNumber == "2025-0042")
    }
}
