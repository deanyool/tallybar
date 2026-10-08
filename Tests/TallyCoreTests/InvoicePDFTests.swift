import Foundation
import PDFKit
import Testing
@testable import TallyCore

@Suite("Invoice PDF")
struct InvoicePDFTests {
    private let calendar = Fixtures.calendar()
    private let locale = Locale(identifier: "en_US")
    private let period = DateInterval(
        start: Fixtures.at("2025-10-01T00:00:00-04:00"),
        end: Fixtures.at("2025-11-01T00:00:00-04:00")
    )

    private func invoice(days: Int, note: String = "Design work", tax: Decimal = 13) throws -> Invoice {
        var (ledger, client) = Fixtures.ledger(rate: 120)
        client.billingAddress = "48 Example Road\nHalifax, NS"
        ledger.updateClient(client)
        ledger.settings.business = BusinessProfile(
            name: "Test Studio", address: "1 Sample St", email: "billing@studio.example",
            taxID: "RT-1", paymentInstructions: "Pay by bank transfer."
        )
        let first = Fixtures.at("2025-10-01T09:00:00-04:00")
        for index in 0..<days {
            let start = first.addingTimeInterval(TimeInterval(index) * 3600 * 2)
            ledger.entries.append(TimeEntry(clientID: client.id, start: start, end: start.addingTimeInterval(3600), note: note))
        }
        let request = InvoiceRequest(
            clientID: client.id, period: period, number: "INV-0042",
            issueDate: Fixtures.at("2025-11-01T10:00:00-04:00"),
            grouping: .entry, taxPercent: tax, notes: "Thank you."
        )
        return try ledger.buildInvoice(request, calendar: calendar)
    }

    private func render(_ invoice: Invoice, pageSize: InvoicePageSize = .letter) throws -> PDFDocument {
        let data = try InvoicePDF(invoice: invoice, pageSize: pageSize, locale: locale, timeZone: Fixtures.toronto).render()
        return try #require(PDFDocument(data: data))
    }

    private func text(of document: PDFDocument) -> String {
        (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined(separator: "\n")
    }

    @Test func printsTheFactsThatMatter() throws {
        let document = try render(try invoice(days: 2))
        let text = text(of: document)
        #expect(document.pageCount == 1)
        for expected in ["Invoice", "INV-0042", "Test Studio", "Acme Test Co", "48 Example Road", "Design work",
                         "$240.00", "$31.20", "$271.20", "Pay by bank transfer.", "Thank you.", "Page 1 of 1",
                         "Oct 1, 2025 to Oct 31, 2025", "Dec 1, 2025"] {
            #expect(text.contains(expected), "missing \(expected)")
        }
    }

    @Test func zeroTaxLeavesOutTheTaxRow() throws {
        let document = try render(try invoice(days: 1, tax: 0))
        #expect(!text(of: document).contains("Tax ("))
    }

    @Test func letterAndA4HaveTheirRealPageSizes() throws {
        let invoice = try invoice(days: 1)
        let letter = try render(invoice).page(at: 0)?.bounds(for: .mediaBox)
        let a4 = try render(invoice, pageSize: .a4).page(at: 0)?.bounds(for: .mediaBox)
        #expect(letter?.size == CGSize(width: 612, height: 792))
        #expect(a4?.width.rounded() == 595)
        #expect(a4?.height.rounded() == 842)
    }

    @Test func longInvoicesPaginateAndKeepTheTotalAtTheEnd() throws {
        let document = try render(try invoice(days: 60))
        #expect(document.pageCount > 1)
        let pages = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }
        #expect(pages.last?.contains("Total due") == true)
        #expect(pages.dropLast().allSatisfy { !$0.contains("Total due") })
        #expect(pages.first?.contains("Page 1 of \(document.pageCount)") == true)
        #expect(pages[1].contains("continued"))
        let rows = pages.reduce(0) { $0 + $1.components(separatedBy: "Design work").count - 1 }
        #expect(rows == 60)
    }

    @Test func totalsThatDoNotFitMoveToTheirOwnPageWhole() throws {
        // Find a length where the rows fill page one exactly; the closing block must not split.
        for days in 18...30 {
            let document = try render(try invoice(days: days))
            let pages = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }
            let holders = pages.filter { $0.contains("Total due") }
            #expect(holders.count == 1)
            #expect(holders[0].contains("Pay by bank transfer."))
        }
    }

    @Test func longDescriptionsWrapRatherThanClip() throws {
        let long = (1...40).map { "word\($0)" }.joined(separator: " ")
        let document = try render(try invoice(days: 1, note: long))
        let text = text(of: document).replacingOccurrences(of: "\n", with: " ")
        #expect(text.contains("word1 "))
        #expect(text.contains("word40"))
    }

    @Test func aRunawayNoteIsCutToFitOnePage() throws {
        let huge = String(repeating: "A very long note that keeps going. ", count: 400)
        let document = try render(try invoice(days: 1, note: huge))
        #expect(document.pageCount == 1)
        #expect(text(of: document).contains("…"))
    }

    @Test func carriesDocumentMetadata() throws {
        let attributes = try render(try invoice(days: 1)).documentAttributes
        #expect(attributes?[PDFDocumentAttribute.titleAttribute] as? String == "Invoice INV-0042")
        #expect(attributes?[PDFDocumentAttribute.authorAttribute] as? String == "Test Studio")
    }
}
