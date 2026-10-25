import AppKit
import Combine
import SwiftUI
import TallyCore

/// Connects the model to the system: the tick timer, sleep and wake, the global hotkey,
/// the windows. All of the decisions live in `AppModel`; this class only wires it up.
@MainActor
public final class AppController: ObservableObject {
    public let model: AppModel
    public let windows = WindowManager()

    private let hotKey = GlobalHotKey()
    private var timer: Timer?
    private var subscriptions: Set<AnyCancellable> = []

    private static let tickInterval: TimeInterval = 15

    public init(model: AppModel) {
        self.model = model
        observeModel()
        startTicking()
    }

    /// Reads the data location from `TALLYBAR_DATA_DIR` when set, so a test run or a
    /// second copy of the app can keep its own ledger.
    public static var storeURL: URL {
        if let directory = ProcessInfo.processInfo.environment["TALLYBAR_DATA_DIR"], !directory.isEmpty {
            return URL(filePath: directory, directoryHint: .isDirectory).appending(path: "ledger.json")
        }
        return LedgerStore.defaultURL
    }

    public static func live() -> AppController {
        AppController(model: .launch(store: LedgerStore(url: storeURL)))
    }

    public var menuActions: MenuActions {
        MenuActions(
            openTimesheet: { [weak self] in self?.showTimesheet() },
            openInvoice: { [weak self] in self?.showInvoice() },
            openExport: { [weak self] in self?.showExport() },
            openSettings: { [weak self] in self?.showSettings() },
            quit: { NSApp.terminate(nil) }
        )
    }

    private func showTimesheet() {
        windows.show(id: "timesheet", title: "Timesheet") { TimesheetView(model: model) }
    }

    private func showInvoice() {
        windows.close(id: "invoice")
        windows.show(id: "invoice", title: "New Invoice") { InvoiceView(model: model) }
    }

    private func showExport() {
        windows.show(id: "export", title: "Export CSV") { ExportView(model: model) }
    }

    private func showSettings() {
        windows.show(id: "settings", title: "TallyBar Settings") { SettingsView(model: model) }
    }

    private func startTicking() {
        tick()
        let timer = Timer(timeInterval: AppController.tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.tick() }
            .store(in: &subscriptions)
    }

    private func tick() {
        model.tick(now: Date(), idleSeconds: SystemIdle.seconds)
    }

    private func observeModel() {
        model.$ledger
            .map(\.settings.hotKey)
            .removeDuplicates()
            .sink { [weak self] combo in self?.applyHotKey(combo) }
            .store(in: &subscriptions)

        model.$pendingAway
            .removeDuplicates()
            .sink { [weak self] away in self?.showAwayPrompt(away) }
            .store(in: &subscriptions)

        model.$problem
            .compactMap { $0 }
            .sink { [weak self] message in self?.showProblem(message) }
            .store(in: &subscriptions)
    }

    private func applyHotKey(_ combo: HotKeyCombo?) {
        guard let combo else {
            hotKey.unregister()
            return
        }
        let registered = hotKey.register(combo) { [weak self] in self?.model.toggle() }
        model.hotKeyRegistration(combo, succeeded: registered)
    }

    private func showAwayPrompt(_ away: AwayPeriod?) {
        guard let away else {
            windows.close(id: "away")
            return
        }
        // Deferred because this can fire during launch, before the app is ready for windows.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.model.pendingAway == away else { return }
            self.windows.showPanel(id: "away", title: "TallyBar") {
                IdlePromptView(
                    away: away,
                    clientName: self.model.runningClient?.name ?? "a client",
                    timeZone: self.model.timeZone
                ) { [weak self] decision in
                    self?.model.answerAway(decision)
                }
            }
        }
    }

    private func showProblem(_ message: String) {
        // Deferred so an alert raised during launch does not run inside SwiftUI's setup.
        DispatchQueue.main.async { [weak self] in
            let alert = NSAlert()
            alert.messageText = "TallyBar"
            alert.informativeText = message
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            self?.model.problem = nil
        }
    }
}
