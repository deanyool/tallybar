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

    private var timer: Timer?
    private var subscriptions: Set<AnyCancellable> = []

    private static let tickInterval: TimeInterval = 15

    public init(model: AppModel) {
        self.model = model
        observeModel()
        startTicking()
    }

    public static func live() -> AppController {
        AppController(model: .launch(store: LedgerStore(url: LedgerStore.defaultURL)))
    }

    public var menuActions: MenuActions {
        MenuActions(
            openTimesheet: { [weak self] in self?.showTimesheet() },
            openSettings: { [weak self] in self?.showSettings() },
            quit: { NSApp.terminate(nil) }
        )
    }

    private func showTimesheet() {
        windows.show(id: "timesheet", title: "Timesheet") { TimesheetView(model: model) }
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
        model.tick(now: Date())
    }

    private func observeModel() {
        model.$problem
            .compactMap { $0 }
            .sink { [weak self] message in self?.showProblem(message) }
            .store(in: &subscriptions)
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
