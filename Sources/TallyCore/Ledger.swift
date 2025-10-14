import Foundation

/// The whole document: everything TallyBar knows, in one value. All changes go through
/// its mutating methods, which is why the tracking rules can be tested without any UI.
public struct Ledger: Codable, Equatable, Sendable {
    public var clients: [Client]
    public var entries: [TimeEntry]
    public var running: RunningSession?
    public var settings: TallySettings
    /// Remembered so the global hotkey can restart the last client with no UI at all.
    public var lastClientID: UUID?

    public init(
        clients: [Client] = [],
        entries: [TimeEntry] = [],
        running: RunningSession? = nil,
        settings: TallySettings = TallySettings()
    ) {
        self.clients = clients
        self.entries = entries
        self.running = running
        self.settings = settings
        self.lastClientID = nil
    }

    public func client(id: UUID) -> Client? {
        clients.first { $0.id == id }
    }

    /// Clients shown in the menu, in the order they were added.
    public var activeClients: [Client] {
        clients.filter { !$0.isArchived }
    }

    /// A calendar honoring the week start setting.
    public func calendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2
        return calendar
    }
}
