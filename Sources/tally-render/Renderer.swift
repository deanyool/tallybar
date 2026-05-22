import AppKit
import PDFKit
import SwiftUI
import TallyCore
import TallyUI

/// Draws views through a real `NSHostingView` in an offscreen window, so AppKit-backed
/// controls such as pickers and text fields render exactly as they do in the app.
@MainActor
struct Renderer {
    let output: URL

    func renderAll() throws {
        let ledger = SampleLedger.make()
        let model = AppModel(
            ledger: ledger,
            store: nil,
            now: SampleLedger.now,
            timeZone: SampleLedger.timeZone,
            locale: SampleLedger.locale,
            hasLiveClock: false
        )
        let panel = MenuPanel(model: model, actions: MenuActions())

        try snapshot(panel, name: "menu-light", dark: false)
        try snapshot(panel, name: "menu-dark", dark: true)
        try snapshot(idlePrompt, name: "idle-prompt", dark: false)
        try snapshot(TimesheetView(model: model).frame(width: 680, height: 560), name: "timesheet", dark: false)
        try snapshot(InvoiceView(model: model), name: "new-invoice", dark: false)
        try snapshot(
            GeneralSettingsView(model: model, launchAtLogin: previewLaunchControl).frame(width: 520, height: 420),
            name: "settings",
            dark: true
        )
        try renderInvoice(ledger)
        try renderCSV(ledger)
    }

    private var previewLaunchControl: LaunchAtLoginControl {
        LaunchAtLoginControl(isAvailable: true, isEnabled: { true }, setEnabled: { _ in })
    }

    private var idlePrompt: IdlePromptView {
        let start = SampleLedger.date("2025-11-05T15:02:00")
        let away = AwayPeriod(start: start, end: start.addingTimeInterval(23 * 60))
        return IdlePromptView(away: away, clientName: "Lumen Coffee Roasters", timeZone: SampleLedger.timeZone) { _ in }
    }

    private func october(_ ledger: Ledger) -> DateInterval {
        ledger.calendar(timeZone: SampleLedger.timeZone).monthInterval(containing: SampleLedger.date("2025-10-15T12:00:00"))
    }

    private func renderInvoice(_ ledger: Ledger) throws {
        guard let client = ledger.clients.first else { return }
        let request = InvoiceRequest(
            clientID: client.id,
            period: october(ledger),
            number: "INV-0042",
            issueDate: SampleLedger.date("2025-11-01T10:00:00"),
            grouping: .day,
            taxPercent: 13,
            notes: "Thanks for the great project."
        )
        let invoice = try ledger.buildInvoice(request, calendar: ledger.calendar(timeZone: SampleLedger.timeZone))
        let data = try InvoicePDF(
            invoice: invoice,
            pageSize: .letter,
            locale: SampleLedger.locale,
            timeZone: SampleLedger.timeZone
        ).render()
        let url = output.appending(path: "sample-invoice.pdf")
        try data.write(to: url, options: .atomic)
        try rasterize(pdf: data, name: "sample-invoice")
    }

    private func renderCSV(_ ledger: Ledger) throws {
        let text = ledger.csv(in: october(ledger), calendar: ledger.calendar(timeZone: SampleLedger.timeZone))
        try Data(text.utf8).write(to: output.appending(path: "sample-export.csv"), options: .atomic)
    }

    private func rasterize(pdf data: Data, name: String) throws {
        guard let page = PDFDocument(data: data)?.page(at: 0) else { throw RenderError.badPDF }
        let bounds = page.bounds(for: .mediaBox)
        let image = page.thumbnail(of: CGSize(width: bounds.width * 2, height: bounds.height * 2), for: .mediaBox)
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { throw RenderError.badImage(name) }
        try png.write(to: output.appending(path: "\(name).png"), options: .atomic)
    }

    private func snapshot(_ view: some View, name: String, dark: Bool, scale: CGFloat? = nil) throws {
        let root = view
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.locale, SampleLedger.locale)
            .environment(\.timeZone, SampleLedger.timeZone)
        let host = NSHostingView(rootView: root)
        let size = host.fittingSize
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))

        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw RenderError.badImage(name) }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { throw RenderError.badImage(name) }
        try png.write(to: output.appending(path: "\(name).png"), options: .atomic)
    }
}

enum RenderError: Error {
    case badPDF
    case badImage(String)
}
