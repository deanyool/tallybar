import Foundation
import Testing
@testable import TallyCore

@Suite("CSV export")
struct CSVExporterTests {
    private let calendar = Fixtures.calendar()
    private let october = DateInterval(
        start: Fixtures.at("2025-10-01T00:00:00-04:00"),
        end: Fixtures.at("2025-11-01T00:00:00-04:00")
    )

    private func rows(_ csv: String) -> [String] {
        csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
    }

    @Test func writesAHeaderAndOneRow() {
        var (ledger, client) = Fixtures.ledger(rate: Decimal(string: "120.5")!)
        ledger.entries = [TimeEntry(
            clientID: client.id,
            start: Fixtures.at("2025-10-06T09:05:00-04:00"),
            end: Fixtures.at("2025-10-06T10:35:00-04:00"),
            note: "Design"
        )]
        let lines = rows(ledger.csv(in: october, calendar: calendar))
        #expect(lines == [
            "date,start,end,hours,duration,client,note,rate,amount,currency,invoice",
            "2025-10-06,2025-10-06T09:05:00-04:00,2025-10-06T10:35:00-04:00,1.50,1:30,Acme Test Co,Design,120.50,180.75,USD,"
        ])
    }

    @Test func usesCRLFLineEndings() {
        let (ledger, _) = Fixtures.ledger()
        #expect(ledger.csv(in: october, calendar: calendar).hasSuffix("invoice\r\n"))
    }

    @Test func splitsAtMidnightByDefault() {
        var (ledger, client) = Fixtures.ledger()
        ledger.entries = [TimeEntry(
            clientID: client.id,
            start: Fixtures.at("2025-10-15T23:00:00-04:00"),
            end: Fixtures.at("2025-10-16T01:00:00-04:00")
        )]
        let lines = rows(ledger.csv(in: october, calendar: calendar))
        #expect(lines.count == 3)
        #expect(lines[1].hasPrefix("2025-10-15,"))
        #expect(lines[2].hasPrefix("2025-10-16,"))
    }

    @Test func canKeepSessionsWhole() {
        var (ledger, client) = Fixtures.ledger()
        ledger.entries = [TimeEntry(
            clientID: client.id,
            start: Fixtures.at("2025-10-15T23:00:00-04:00"),
            end: Fixtures.at("2025-10-16T01:00:00-04:00")
        )]
        let lines = rows(ledger.csv(in: october, options: CSVOptions(splitAtMidnight: false), calendar: calendar))
        #expect(lines.count == 2)
        #expect(lines[1].contains(",2.00,2:00,"))
    }

    @Test func repeatedHourStaysUnambiguous() {
        let november = DateInterval(
            start: Fixtures.at("2025-11-01T00:00:00-04:00"),
            end: Fixtures.at("2025-12-01T00:00:00-05:00")
        )
        var (ledger, client) = Fixtures.ledger()
        ledger.entries = [TimeEntry(
            clientID: client.id,
            start: Fixtures.at("2025-11-02T01:30:00-04:00"),
            end: Fixtures.at("2025-11-02T01:30:00-05:00")
        )]
        let line = rows(ledger.csv(in: november, calendar: calendar))[1]
        #expect(line.contains("2025-11-02T01:30:00-04:00,2025-11-02T01:30:00-05:00,1.00"))
    }

    @Test(arguments: [
        ("plain", "plain"),
        ("a,b", "\"a,b\""),
        ("say \"hi\"", "\"say \"\"hi\"\"\""),
        ("=SUM(A1:A9)", "'=SUM(A1:A9)"),
        ("+1 call", "'+1 call"),
        ("@handle", "'@handle"),
        ("-12.50", "-12.50"),
        ("-rm thing", "'-rm thing"),
        ("=1,2", "\"'=1,2\"")
    ])
    func escapesFields(input: String, expected: String) {
        #expect(CSVRow.field(input) == expected)
    }

    @Test func excelModeStartsWithAByteOrderMark() {
        let (ledger, _) = Fixtures.ledger()
        let csv = ledger.csv(in: october, options: CSVOptions(excelCompatible: true), calendar: calendar)
        #expect(csv.unicodeScalars.first == "\u{FEFF}")
    }

    @Test func roundingOptionChangesHoursAndAmounts() {
        var (ledger, client) = Fixtures.ledger()
        ledger.settings.billingRounding = BillingRounding(incrementMinutes: 15, mode: .up)
        ledger.entries = [TimeEntry(
            clientID: client.id,
            start: Fixtures.at("2025-10-06T09:00:00-04:00"),
            end: Fixtures.at("2025-10-06T09:05:00-04:00")
        )]
        let exact = rows(ledger.csv(in: october, calendar: calendar))[1]
        let rounded = rows(ledger.csv(in: october, options: CSVOptions(applyRounding: true), calendar: calendar))[1]
        #expect(exact.contains(",0.08,0:05,"))
        #expect(rounded.contains(",0.25,0:15,"))
        #expect(rounded.contains(",25.00,USD"))
    }

    @Test func showsTheInvoiceNumber() {
        var (ledger, client) = Fixtures.ledger()
        ledger.entries = [TimeEntry(
            clientID: client.id,
            start: Fixtures.at("2025-10-06T09:00:00-04:00"),
            end: Fixtures.at("2025-10-06T10:00:00-04:00"),
            invoiceNumber: "INV-0003"
        )]
        #expect(rows(ledger.csv(in: october, calendar: calendar))[1].hasSuffix(",USD,INV-0003"))
    }

    @Test func filtersByClientAndSortsOldestFirst() {
        var (ledger, client) = Fixtures.ledger()
        let other = ledger.addClient(name: "Other", hourlyRate: 1)
        ledger.entries = [
            TimeEntry(clientID: client.id, start: Fixtures.at("2025-10-07T09:00:00-04:00"), end: Fixtures.at("2025-10-07T10:00:00-04:00")),
            TimeEntry(clientID: client.id, start: Fixtures.at("2025-10-06T09:00:00-04:00"), end: Fixtures.at("2025-10-06T10:00:00-04:00")),
            TimeEntry(clientID: other.id, start: Fixtures.at("2025-10-05T09:00:00-04:00"), end: Fixtures.at("2025-10-05T10:00:00-04:00"))
        ]
        let lines = rows(ledger.csv(in: october, clientID: client.id, calendar: calendar))
        #expect(lines.count == 3)
        #expect(lines[1].hasPrefix("2025-10-06"))
    }
}
