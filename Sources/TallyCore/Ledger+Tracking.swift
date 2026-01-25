import Foundation

public extension Ledger {
    /// Starts timing `clientID` at `now`. Starting while another client runs closes that
    /// session first, so switching clients is one click. Starting the client that is
    /// already running does nothing.
    mutating func start(clientID: UUID, note: String = "", at now: Date) {
        guard client(id: clientID) != nil, running?.clientID != clientID else { return }
        stop(at: now)
        running = RunningSession(clientID: clientID, start: now.wholeSecond, note: note)
        lastClientID = clientID
        lastHeartbeat = now.wholeSecond
    }

    /// Stops the timer and records the entry, unless it was short enough to be a misclick.
    @discardableResult
    mutating func stop(at now: Date) -> TimeEntry? {
        guard let session = running else { return nil }
        running = nil
        lastHeartbeat = nil
        return record(session, until: now.wholeSecond)
    }

    /// What the global hotkey does: stop if running, otherwise resume the last client
    /// (falling back to the first active one). Archived clients are skipped.
    mutating func toggle(at now: Date) {
        if running != nil {
            stop(at: now)
        } else if let target = resumeTarget {
            start(clientID: target, at: now)
        }
    }

    /// Updates the note on the running session.
    mutating func setRunningNote(_ note: String) {
        running?.note = note
    }

    /// Applies the person's answer to "you were away".
    mutating func resolve(_ away: AwayPeriod, decision: AwayDecision, at now: Date) {
        guard decision != .keep, let session = running else { return }
        let leftAt = max(away.start.wholeSecond, session.start)
        running = nil
        lastHeartbeat = nil
        record(session, until: leftAt)
        if decision == .discard {
            running = RunningSession(clientID: session.clientID, start: now.wholeSecond, note: session.note)
            lastHeartbeat = now.wholeSecond
        }
    }

    /// The away period to ask about after a launch, if the app died mid-session.
    /// The time since the last heartbeat is unaccounted for, whatever the cause.
    func awayAfterRelaunch(at now: Date, threshold: TimeInterval) -> AwayPeriod? {
        guard running != nil, let heartbeat = lastHeartbeat,
              threshold > 0, now.timeIntervalSince(heartbeat) >= threshold else { return nil }
        return AwayPeriod(start: heartbeat, end: now)
    }

    private var resumeTarget: UUID? {
        if let last = lastClientID, client(id: last)?.isArchived == false {
            return last
        }
        return activeClients.first?.id
    }

    @discardableResult
    private mutating func record(_ session: RunningSession, until end: Date) -> TimeEntry? {
        let entry = TimeEntry(clientID: session.clientID, start: session.start, end: end, note: session.note)
        guard entry.seconds >= settings.minimumEntrySeconds, entry.seconds > 0 else { return nil }
        entries.append(entry)
        return entry
    }
}
