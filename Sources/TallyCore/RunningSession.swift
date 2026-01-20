import Foundation

/// The timer currently ticking. It is part of the saved ledger, so quitting the app or
/// a crash never loses the session.
public struct RunningSession: Hashable, Codable, Sendable {
    public var clientID: UUID
    public var start: Date
    public var note: String

    public init(clientID: UUID, start: Date, note: String = "") {
        self.clientID = clientID
        self.start = start
        self.note = note
    }

    /// Whole seconds elapsed at `now`.
    public func elapsed(at now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(start).rounded(.down)))
    }
}

/// A stretch of a running session when nobody was at the machine.
public struct AwayPeriod: Hashable, Sendable, Identifiable {
    public var start: Date
    public var end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public var id: Date { start }

    public var seconds: Int {
        max(0, Int(end.timeIntervalSince(start).rounded()))
    }
}

/// What to do with an away period once the person is back.
public enum AwayDecision: Sendable {
    /// Count the time. Nothing changes.
    case keep
    /// Close the session at the moment they left and carry on from now.
    case discard
    /// Close the session at the moment they left and stop.
    case discardAndStop
}
