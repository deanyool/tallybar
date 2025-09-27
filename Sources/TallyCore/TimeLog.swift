import Foundation

public struct Entry: Identifiable, Codable {
    public var id = UUID()
    public var client: String
    public var start: Date
    public var end: Date
}

public struct TimeLog: Codable {
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

    /// seconds tracked today, only counts finished entries
    public var todayTotal: TimeInterval {
        entries
            .filter { Calendar.current.isDateInToday($0.start) }
            .reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
    }

    static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("tally.json")
    }

    public static func load() -> TimeLog {
        guard let data = try? Data(contentsOf: fileURL) else { return TimeLog() }
        return (try? JSONDecoder().decode(TimeLog.self, from: data)) ?? TimeLog()
    }

    public func save() {
        let data = try? JSONEncoder().encode(self)
        try? data?.write(to: TimeLog.fileURL)
    }
}
