import CoreGraphics
import CoreText
import Foundation

/// Shared measurements for the invoice page, in points.
enum InvoiceStyle {
    static let margin: CGFloat = 54
    static let rowPadding: CGFloat = 6
    static let footerHeight: CGFloat = 36
    static let tableHeaderHeight: CGFloat = 24
    static let firstPageHeaderHeight: CGFloat = 214
    static let laterPageHeaderHeight: CGFloat = 44

    // Computed because CTFont is not Sendable, so it cannot sit in a shared constant.
    static var title: CTFont { font(24, bold: true) }
    static var heading: CTFont { font(9, bold: true) }
    static var body: CTFont { font(10, bold: false) }
    static var bodyBold: CTFont { font(10, bold: true) }
    static var total: CTFont { font(13, bold: true) }
    static var small: CTFont { font(8, bold: false) }

    static let ink = CGColor(srgbRed: 0.11, green: 0.12, blue: 0.14, alpha: 1)
    static let muted = CGColor(srgbRed: 0.42, green: 0.45, blue: 0.50, alpha: 1)
    static let rule = CGColor(srgbRed: 0.86, green: 0.87, blue: 0.89, alpha: 1)
    static let accent = CGColor(srgbRed: 0.13, green: 0.44, blue: 0.40, alpha: 1)

    private static func font(_ size: CGFloat, bold: Bool) -> CTFont {
        let base = CTFontCreateUIFontForLanguage(bold ? .emphasizedSystem : .system, size, nil)
        return base ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
    }
}

public extension InvoicePageSize {
    var size: CGSize {
        switch self {
        case .letter: return CGSize(width: 612, height: 792)
        }
    }
}

/// The columns of the line item table, left to right.
struct InvoiceColumns {
    let date: CGRect
    let description: CGRect
    let hours: CGRect
    let rate: CGRect
    let amount: CGRect

    init(contentWidth: CGFloat, left: CGFloat) {
        let dateWidth: CGFloat = 70
        let hoursWidth: CGFloat = 48
        let rateWidth: CGFloat = 72
        let amountWidth: CGFloat = 84
        let gap: CGFloat = 10
        let descriptionWidth = contentWidth - dateWidth - hoursWidth - rateWidth - amountWidth - 4 * gap
        func column(_ start: CGFloat, _ width: CGFloat) -> CGRect {
            CGRect(x: start, y: 0, width: width, height: 0)
        }
        date = column(left, dateWidth)
        description = column(date.maxX + gap, descriptionWidth)
        hours = column(description.maxX + gap, hoursWidth)
        rate = column(hours.maxX + gap, rateWidth)
        amount = column(rate.maxX + gap, amountWidth)
    }
}

/// Splits line items across pages. Measuring happens up front because the footer
/// prints "Page 1 of 3", so the page count must be known before anything is drawn.
struct InvoicePagination {
    let pages: [[InvoiceLine]]

    /// - Parameter rowHeight: height of a line item, which depends on wrapped text.
    /// - Parameter closingHeight: the totals and notes block, kept together on the last page.
    init(lines: [InvoiceLine], pageHeight: CGFloat, closingHeight: CGFloat, rowHeight: (InvoiceLine) -> CGFloat) {
        let top = pageHeight - 2 * InvoiceStyle.margin - InvoiceStyle.footerHeight - InvoiceStyle.tableHeaderHeight
        var result: [[InvoiceLine]] = [[]]
        var room = top - InvoiceStyle.firstPageHeaderHeight
        for line in lines {
            let height = rowHeight(line)
            if height > room, !(result[result.count - 1].isEmpty) {
                result.append([])
                room = top - InvoiceStyle.laterPageHeaderHeight
            }
            result[result.count - 1].append(line)
            room -= height
        }
        pages = result
    }
}

/// Text helpers over Core Text, with a top-left origin so layout code can read downward.
struct PDFCanvas {
    let context: CGContext
    let pageHeight: CGFloat

    enum Alignment {
        case left, right
    }

    static func height(of text: String, font: CTFont, width: CGFloat) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let setter = CTFramesetterCreateWithAttributedString(attributed(text, font: font, color: nil, .left))
        let size = CTFramesetterSuggestFrameSizeWithConstraints(
            setter, CFRange(), nil, CGSize(width: width, height: .greatestFiniteMagnitude), nil
        )
        return ceil(size.height)
    }

    /// Draws wrapped text with its top edge at `top` and returns the height used.
    @discardableResult
    func draw(
        _ text: String,
        left: CGFloat,
        top: CGFloat,
        width: CGFloat,
        font: CTFont,
        color: CGColor = InvoiceStyle.ink,
        alignment: Alignment = .left
    ) -> CGFloat {
        let height = PDFCanvas.height(of: text, font: font, width: width)
        guard height > 0 else { return 0 }
        let string = PDFCanvas.attributed(text, font: font, color: color, alignment)
        let setter = CTFramesetterCreateWithAttributedString(string)
        let rect = CGRect(x: left, y: pageHeight - top - height, width: width, height: height)
        let frame = CTFramesetterCreateFrame(setter, CFRange(), CGPath(rect: rect, transform: nil), nil)
        CTFrameDraw(frame, context)
        return height
    }

    func rule(left: CGFloat, right: CGFloat, top: CGFloat, color: CGColor = InvoiceStyle.rule, width: CGFloat = 0.75) {
        context.setStrokeColor(color)
        context.setLineWidth(width)
        context.move(to: CGPoint(x: left, y: pageHeight - top))
        context.addLine(to: CGPoint(x: right, y: pageHeight - top))
        context.strokePath()
    }

    private static func attributed(
        _ text: String,
        font: CTFont,
        color: CGColor?,
        _ alignment: Alignment
    ) -> CFAttributedString {
        var textAlignment: CTTextAlignment = alignment == .right ? .right : .left
        let paragraph = withUnsafePointer(to: &textAlignment) { pointer in
            var setting = CTParagraphStyleSetting(
                spec: .alignment,
                valueSize: MemoryLayout<CTTextAlignment>.size,
                value: pointer
            )
            return CTParagraphStyleCreate(&setting, 1)
        }
        var attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTParagraphStyleAttributeName: paragraph
        ]
        if let color {
            attributes[kCTForegroundColorAttributeName] = color
        }
        return CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)
    }
}
