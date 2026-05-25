import AppKit
import SwiftUI
import Testing
import TallyCore
@testable import TallyUI

/// Lays out each screen in a hosting view so a crash in a body shows up in the test run.
@MainActor
@Suite("Views")
struct ViewSmokeTests {
    private func model(clients: Int = 2, running: Bool = true) -> AppModel {
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        var ledger = Ledger()
        for index in 0..<clients {
            ledger.addClient(name: "Client \(index)", hourlyRate: 100)
        }
        if running, let first = ledger.clients.first {
            ledger.start(clientID: first.id, at: now.addingTimeInterval(-600))
        }
        return AppModel(ledger: ledger, store: nil, now: now, hasLiveClock: false)
    }

    private func layOut(_ view: some View) -> CGSize {
        let host = NSHostingView(rootView: view)
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    @Test func menuPanelHasItsFixedWidth() {
        let size = layOut(MenuPanel(model: model(), actions: MenuActions()))
        #expect(size.width == Theme.panelWidth)
        #expect(size.height > 100)
    }

    @Test func emptyMenuPanelInvitesAClient() {
        #expect(layOut(MenuPanel(model: model(clients: 0, running: false), actions: MenuActions())).height > 100)
    }

    @Test func secondaryScreensLayOut() {
        let model = model()
        #expect(layOut(TimesheetView(model: model)).width >= 620)
        #expect(layOut(InvoiceView(model: model)).width == 460)
        #expect(layOut(ExportView(model: model)).width == 400)
        #expect(layOut(SettingsView(model: model)).width == 520)
    }

    @Test func windowsOpenOnceAndClose() {
        _ = NSApplication.shared
        let windows = WindowManager()
        windows.show(id: "one", title: "One") { Text("first") }
        windows.show(id: "one", title: "One") { Text("second") }
        #expect(windows.openWindowIDs == ["one"])
        windows.close(id: "one")
        #expect(windows.openWindowIDs.isEmpty)
    }

    @Test func goalRingDescribesItself() {
        let ring = GoalRing(goal: WeeklyGoal(trackedSeconds: 3600, goalHours: 2))
        #expect(layOut(ring.frame(width: 50, height: 50)).width == 50)
    }

    @Test func idlePromptAnswers() {
        var answered: AwayDecision?
        let away = AwayPeriod(start: Date(), end: Date().addingTimeInterval(1380))
        let prompt = IdlePromptView(away: away, clientName: "Acme") { answered = $0 }
        #expect(layOut(prompt).width == 380)
        prompt.answer(.keep)
        #expect(answered == .keep)
    }
}
