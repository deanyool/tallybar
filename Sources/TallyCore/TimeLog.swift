import Foundation

public struct Entry: Identifiable {
    public let id = UUID()
    public var client: String
    public var start: Date
    public var end: Date
}

public struct TimeLog {
    public var clients = ["Client A", "Client B"]
    public var entries: [Entry] = []
    public var current: String?
    public var startedAt: Date?

    public init() {}

    public mutating func toggle(_ client: String, now: Date = Date()) {
        if let current = current, let startedAt = startedAt {
            entries.append(Entry(client: current, start: startedAt, end: now))
        }
        if current == client {
            current = nil
            startedAt = nil
        } else {
            current = client
            startedAt = now
        }
    }
}
