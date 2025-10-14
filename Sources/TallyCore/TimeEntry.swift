import Foundation

public extension Date {
    /// This date with any fraction of a second dropped. Entries hold whole seconds so
    /// durations are exact integers and survive the JSON round trip unchanged.
    var wholeSecond: Date {
        Date(timeIntervalSince1970: timeIntervalSince1970.rounded(.down))
    }
}

/// A finished block of work. `start` and `end` are absolute instants, which is what
/// makes durations correct across daylight saving changes: the wall clock can repeat
/// an hour, but the distance between two instants cannot.
public struct TimeEntry: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var clientID: UUID
    public var start: Date
    public var end: Date
    public var note: String

    public init(
        id: UUID = UUID(),
        clientID: UUID,
        start: Date,
        end: Date,
        note: String = ""
    ) {
        self.id = id
        self.clientID = clientID
        self.start = start
        self.end = end
        self.note = note
    }

    /// Length in whole seconds.
    public var seconds: Int {
        max(0, Int(end.timeIntervalSince(start).rounded()))
    }

    /// The part of this entry inside `interval`, or nil when they do not overlap.
    public func clipped(to interval: DateInterval) -> TimeEntry? {
        let clippedStart = max(start, interval.start)
        let clippedEnd = min(end, interval.end)
        guard clippedStart < clippedEnd else { return nil }
        var copy = self
        copy.start = clippedStart
        copy.end = clippedEnd
        return copy
    }
}

extension TimeEntry: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, clientID, start, end, note
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        clientID = try container.decode(UUID.self, forKey: .clientID)
        start = try container.decode(Date.self, forKey: .start)
        end = try container.decode(Date.self, forKey: .end)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}
