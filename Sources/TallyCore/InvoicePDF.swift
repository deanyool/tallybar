import CoreGraphics
import CoreText
import Foundation

public enum InvoicePDFError: Error {
    case couldNotCreateContext
}

/// Draws an invoice with Core Graphics and Core Text, so it needs no window, no WebKit
/// and no main thread, and the same input gives the same document in a test.
public struct InvoicePDF {
    let invoice: Invoice
    let pageSize: CGSize
    let locale: Locale
    let timeZone: TimeZone

    public init(invoice: Invoice, pageSize: InvoicePageSize, locale: Locale = .current, timeZone: TimeZone = .current) {
        self.invoice = invoice
        self.pageSize = pageSize.size
        self.locale = locale
        self.timeZone = timeZone
    }

    /// The finished PDF.
    public func render() throws -> Data {
        let output = NSMutableData()
        var box = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(data: output as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, documentInfo as CFDictionary) else {
            throw InvoicePDFError.couldNotCreateContext
        }
        let canvas = PDFCanvas(context: context, pageHeight: pageSize.height)
        let pagination = InvoicePagination(
            lines: invoice.lines,
            pageHeight: pageSize.height,
            closingHeight: closingHeight,
            rowHeight: rowHeight(_:)
        )
        for (index, lines) in pagination.pages.enumerated() {
            context.beginPDFPage(nil)
            var top = index == 0 ? drawLetterhead(on: canvas) : drawContinuationHeader(on: canvas)
            if !lines.isEmpty {
                top = drawTable(lines, on: canvas, top: top)
            }
            if index == pagination.pages.count - 1 {
                drawClosing(on: canvas, top: top)
            }
            drawFooter(on: canvas, page: index + 1, of: pagination.pages.count)
            context.endPDFPage()
        }
        context.closePDF()
        return output as Data
    }

    private var documentInfo: [CFString: Any] {
        [
            kCGPDFContextTitle: "Invoice \(invoice.number)",
            kCGPDFContextAuthor: invoice.sender.name,
            kCGPDFContextCreator: "TallyBar \(TallyVersion.current)"
        ]
    }

    private var left: CGFloat { InvoiceStyle.margin }
    private var right: CGFloat { pageSize.width - InvoiceStyle.margin }
    private var contentWidth: CGFloat { right - left }
    private var columns: InvoiceColumns { InvoiceColumns(contentWidth: contentWidth, left: left) }

    private func money(_ value: Money) -> String {
        value.formatted(locale: locale)
    }

    private func date(_ value: Date) -> String {
        value.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, timeZone: timeZone))
    }

    /// The period's last instant is the start of the next day, so step back to name
    /// the last day actually covered.
    private var periodText: String {
        "\(date(invoice.period.start)) to \(date(invoice.period.end.addingTimeInterval(-1)))"
    }

    private func rowHeight(_ line: InvoiceLine) -> CGFloat {
        PDFCanvas.height(of: line.description, font: InvoiceStyle.body, width: columns.description.width)
            + 2 * InvoiceStyle.rowPadding
    }

    private func drawLetterhead(on canvas: PDFCanvas) -> CGFloat {
        let top = InvoiceStyle.margin
        canvas.draw("Invoice", left: left, top: top, width: 200, font: InvoiceStyle.title, color: InvoiceStyle.accent)

        let facts: [(String, String)] = [
            ("Number", invoice.number),
            ("Issued", date(invoice.issueDate)),
            ("Due", date(invoice.dueDate)),
            ("Period", periodText)
        ]
        var factTop = top + 2
        for (label, value) in facts {
            canvas.draw(label, left: right - 250, top: factTop, width: 50, font: InvoiceStyle.heading, color: InvoiceStyle.muted)
            canvas.draw(value, left: right - 200, top: factTop, width: 200, font: InvoiceStyle.body, alignment: .right)
            factTop += 15
        }

        let blockTop = top + 84
        let blockWidth = contentWidth / 2 - 12
        canvas.draw("FROM", left: left, top: blockTop, width: blockWidth, font: InvoiceStyle.heading, color: InvoiceStyle.muted)
        canvas.draw(senderBlock, left: left, top: blockTop + 15, width: blockWidth, font: InvoiceStyle.body)
        let toLeft = left + contentWidth / 2 + 12
        canvas.draw("BILL TO", left: toLeft, top: blockTop, width: blockWidth, font: InvoiceStyle.heading, color: InvoiceStyle.muted)
        canvas.draw(billToBlock, left: toLeft, top: blockTop + 15, width: blockWidth, font: InvoiceStyle.body)
        return InvoiceStyle.margin + InvoiceStyle.firstPageHeaderHeight
    }

    private var senderBlock: String {
        let sender = invoice.sender
        var rows = [sender.name, sender.address, sender.email]
        if !sender.taxID.isEmpty { rows.append("Tax ID: \(sender.taxID)") }
        return rows.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    private var billToBlock: String {
        [invoice.client.name, invoice.client.billingAddress].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    private func drawContinuationHeader(on canvas: PDFCanvas) -> CGFloat {
        let top = InvoiceStyle.margin
        canvas.draw("Invoice \(invoice.number), continued", left: left, top: top, width: contentWidth, font: InvoiceStyle.bodyBold)
        return top + InvoiceStyle.laterPageHeaderHeight
    }

    private func drawTable(_ lines: [InvoiceLine], on canvas: PDFCanvas, top: CGFloat) -> CGFloat {
        let columns = columns
        func header(_ text: String, _ column: CGRect, _ alignment: PDFCanvas.Alignment = .left) {
            canvas.draw(text, left: column.minX, top: top + 6, width: column.width, font: InvoiceStyle.heading,
                        color: InvoiceStyle.muted, alignment: alignment)
        }
        header("DATE", columns.date)
        header("DESCRIPTION", columns.description)
        header("HOURS", columns.hours, .right)
        header("RATE", columns.rate, .right)
        header("AMOUNT", columns.amount, .right)
        var cursor = top + InvoiceStyle.tableHeaderHeight
        canvas.rule(left: left, right: right, top: cursor, color: InvoiceStyle.ink)

        for line in lines {
            let textTop = cursor + InvoiceStyle.rowPadding
            func cell(_ text: String, _ column: CGRect, _ alignment: PDFCanvas.Alignment = .left) {
                canvas.draw(text, left: column.minX, top: textTop, width: column.width, font: InvoiceStyle.body, alignment: alignment)
            }
            cell(line.date.map(date) ?? "", columns.date)
            cell(line.description, columns.description)
            cell(line.hours, columns.hours, .right)
            cell(money(line.rate), columns.rate, .right)
            cell(money(line.amount), columns.amount, .right)
            cursor += rowHeight(line)
            canvas.rule(left: left, right: right, top: cursor)
        }
        return cursor
    }

    private var paymentText: String {
        [invoice.notes, invoice.sender.paymentInstructions].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    private var closingHeight: CGFloat {
        let totals: CGFloat = 96
        let notes = PDFCanvas.height(of: paymentText, font: InvoiceStyle.body, width: contentWidth)
        return totals + (notes > 0 ? notes + 28 : 0)
    }

    private func drawClosing(on canvas: PDFCanvas, top: CGFloat) {
        var cursor = top + 12
        let labelLeft = right - 220
        func row(_ label: String, _ value: String, font: CTFont = InvoiceStyle.body) {
            canvas.draw(label, left: labelLeft, top: cursor, width: 110, font: font)
            canvas.draw(value, left: right - 130, top: cursor, width: 130, font: font, alignment: .right)
        }
        row("Subtotal", money(invoice.subtotal))
        cursor += 16
        if invoice.taxPercent > 0 {
            row("Tax (\(invoice.taxPercent.formatted(.number.locale(locale)))%)", money(invoice.tax))
            cursor += 16
        }
        canvas.rule(left: labelLeft, right: right, top: cursor + 2, color: InvoiceStyle.ink)
        cursor += 9
        row("Total due", money(invoice.total), font: InvoiceStyle.total)
        cursor += 34
        if !paymentText.isEmpty {
            canvas.draw("NOTES", left: left, top: cursor, width: contentWidth, font: InvoiceStyle.heading, color: InvoiceStyle.muted)
            canvas.draw(paymentText, left: left, top: cursor + 14, width: contentWidth, font: InvoiceStyle.body)
        }
    }

    private func drawFooter(on canvas: PDFCanvas, page: Int, of pageCount: Int) {
        let top = pageSize.height - InvoiceStyle.margin + 8
        canvas.draw(invoice.number, left: left, top: top, width: 200, font: InvoiceStyle.small, color: InvoiceStyle.muted)
        canvas.draw("Page \(page) of \(pageCount)", left: right - 100, top: top, width: 100,
                    font: InvoiceStyle.small, color: InvoiceStyle.muted, alignment: .right)
    }
}
