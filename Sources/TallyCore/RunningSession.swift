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
