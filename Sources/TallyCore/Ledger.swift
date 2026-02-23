import Foundation

/// The whole document: everything TallyBar knows, in one value. All changes go through
/// its mutating methods, which is why the tracking rules can be tested without any UI.
public struct Ledger: Equatable, Sendable {
    public static let currentVersion = 2

    public var version: Int
    public var clients: [Client]
    public var entries: [TimeEntry]
    public var running: RunningSession?
    public var settings: TallySettings
    /// Remembered so the global hotkey can restart the last client with no UI at all.
    public var lastClientID: UUID?
    /// Last moment the app knew it was alive during a session, for crash and power-off recovery.
    public var lastHeartbeat: Date?
    public var nextInvoiceNumber: Int

    public init(
        clients: [Client] = [],
        entries: [TimeEntry] = [],
        running: RunningSession? = nil,
        settings: TallySettings = TallySettings()
    ) {
        self.version = Ledger.currentVersion
        self.clients = clients
        self.entries = entries
        self.running = running
        self.settings = settings
        self.lastClientID = nil
        self.lastHeartbeat = nil
        self.nextInvoiceNumber = 1
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
        calendar.firstWeekday = settings.firstWeekday
        return calendar
    }
}

extension Ledger: Codable {
    private enum CodingKeys: String, CodingKey {
        case version, clients, entries, running, settings
        case lastClientID, lastHeartbeat, nextInvoiceNumber
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        clients = try container.decodeIfPresent([Client].self, forKey: .clients) ?? []
        entries = try container.decodeIfPresent([TimeEntry].self, forKey: .entries) ?? []
        running = try container.decodeIfPresent(RunningSession.self, forKey: .running)
        settings = try container.decodeIfPresent(TallySettings.self, forKey: .settings) ?? TallySettings()
        lastClientID = try container.decodeIfPresent(UUID.self, forKey: .lastClientID)
        lastHeartbeat = try container.decodeIfPresent(Date.self, forKey: .lastHeartbeat)
        nextInvoiceNumber = try container.decodeIfPresent(Int.self, forKey: .nextInvoiceNumber) ?? 1
    }
}
