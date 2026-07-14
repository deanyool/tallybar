import Foundation

public extension Ledger {
    /// Every piece of tracked work, including the running session up to `now`.
    func spans(at now: Date) -> [TimeEntry] {
        guard let running else { return entries }
        let live = TimeEntry(clientID: running.clientID, start: running.start, end: now, note: running.note)
        return entries + [live]
    }

    /// Seconds tracked inside `interval`, counting only the part of each entry that
    /// falls within it. A session that crosses midnight counts toward both days.
    func seconds(in interval: DateInterval, clientID: UUID? = nil, at now: Date) -> Int {
        spans(at: now).reduce(0) { total, span in
            if let clientID, span.clientID != clientID { return total }
            return total + (span.clipped(to: interval)?.seconds ?? 0)
        }
    }

    /// Earnings inside `interval`, one `Money` per currency because clients can be billed
    /// in different currencies and those totals must never be added together.
    func earnings(in interval: DateInterval, at now: Date) -> [Money] {
        var totals: [String: Money] = [:]
        for client in clients {
            let seconds = seconds(in: interval, clientID: client.id, at: now)
            guard seconds > 0 else { continue }
            let earned = client.hourlyRate.earned(seconds: seconds)
            totals[earned.currency] = (totals[earned.currency] ?? .zero(earned.currency)) + earned
        }
        return totals.values.sorted { $0.currency < $1.currency }
    }
}
