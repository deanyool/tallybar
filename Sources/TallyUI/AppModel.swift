import Foundation
import SwiftUI
import TallyCore

/// The single source of truth for the UI. It owns the ledger, saves after every change,
/// and turns timer ticks into idle prompts. It knows nothing about AppKit windows, so
/// tests can drive it directly with a temporary store and made-up clocks.
@MainActor
public final class AppModel: ObservableObject {
    @Published public private(set) var ledger: Ledger
    @Published public private(set) var now: Date
    /// The latest problem worth showing, such as a failed save.
    @Published public var problem: String?

    public let timeZone: TimeZone
    private let store: LedgerStore?

    /// - Parameter store: where to save. Nil keeps everything in memory, used for the
    ///   screenshots and for a data file this version must not touch.
    public init(ledger: Ledger, store: LedgerStore?, now: Date, timeZone: TimeZone = .current) {
        self.ledger = ledger
        self.store = store
        self.now = now
        self.timeZone = timeZone
    }

    /// Loads the ledger for a real launch and surfaces anything that went wrong.
    public static func launch(store: LedgerStore, now: Date = Date()) -> AppModel {
        do {
            let model = AppModel(ledger: try store.load(), store: store, now: now)
            return model
        } catch {
            let model = AppModel(ledger: Ledger(), store: nil, now: now)
            model.problem = String(describing: error)
            return model
        }
    }

    public var calendar: Calendar {
        ledger.calendar(timeZone: timeZone)
    }

    /// Applies a change and saves it. Every write in the app comes through here.
    public func update(_ change: (inout Ledger) throws -> Void) rethrows {
        var copy = ledger
        try change(&copy)
        guard copy != ledger else { return }
        ledger = copy
        save()
    }

    private func save() {
        guard let store else { return }
        do {
            try store.save(ledger)
        } catch {
            problem = "Could not save: \(error.localizedDescription)"
        }
    }

    // MARK: Ticking

    public func tick(now: Date) {
        self.now = now
    }

    // MARK: Tracking

    /// One click on a client: start it, switch to it, or stop it if it is already running.
    public func toggle(clientID: UUID, at now: Date = Date()) {
        noteManualAction(at: now)
        update { ledger in
            if ledger.running?.clientID == clientID {
                ledger.stop(at: now)
            } else {
                ledger.start(clientID: clientID, at: now)
            }
        }
    }

    /// The global hotkey.
    public func toggle(at now: Date = Date()) {
        noteManualAction(at: now)
        update { $0.toggle(at: now) }
    }

    private func noteManualAction(at now: Date) {
        self.now = now
    }

    public func setRunningNote(_ note: String) {
        update { $0.setRunningNote(note) }
    }

    // MARK: Reading

    public var todaySeconds: Int {
        ledger.seconds(in: calendar.dayInterval(containing: now), at: now)
    }

    public var weekSeconds: Int {
        ledger.seconds(in: calendar.weekInterval(containing: now), at: now)
    }

    public func todaySeconds(clientID: UUID) -> Int {
        ledger.seconds(in: calendar.dayInterval(containing: now), clientID: clientID, at: now)
    }

    public var todayEarnings: [Money] {
        ledger.earnings(in: calendar.dayInterval(containing: now), at: now)
    }

    public var weeklyGoal: WeeklyGoal {
        ledger.weeklyGoal(at: now, calendar: calendar)
    }

    public var runningClient: Client? {
        ledger.running.flatMap { ledger.client(id: $0.clientID) }
    }

    /// A money amount in the app's locale.
    public func text(for amount: Money) -> String {
        amount.formatted()
    }

    /// Text for a set of per-currency amounts, such as "$412.50 + €90.00".
    public func text(for amounts: [Money]) -> String {
        amounts.map(text(for:)).joined(separator: " + ")
    }

}

public extension AppModel {
    /// A two-way binding to one setting, saved on every change.
    func binding<Value: Sendable>(_ path: WritableKeyPath<TallySettings, Value> & Sendable) -> Binding<Value> {
        Binding(
            get: { [weak self] in
                MainActor.assumeIsolated { self?.ledger.settings[keyPath: path] } ?? TallySettings()[keyPath: path]
            },
            set: { [weak self] value in
                MainActor.assumeIsolated { self?.update { $0.settings[keyPath: path] = value } }
            }
        )
    }
}
