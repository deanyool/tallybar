import Foundation

public extension Ledger {
    /// Every piece of tracked work, including the running session up to `now`.
    func spans(at now: Date) -> [TimeEntry] {
        guard let running else { return entries }
        let live = TimeEntry(clientID: running.clientID, start: running.start, end: now, note: running.note)
        return entries + [live]
    }

    /// Seconds tracked inside `interval`.
    func seconds(in interval: DateInterval, clientID: UUID? = nil, at now: Date) -> Int {
        spans(at: now).reduce(0) { total, span in
            if let clientID, span.clientID != clientID { return total }
            return interval.contains(span.start) ? total + span.seconds : total
        }
    }

    /// Earnings inside `interval`.
    func earnings(in interval: DateInterval, at now: Date) -> [Money] {
        var total = Decimal(0)
        for client in clients {
            let seconds = seconds(in: interval, clientID: client.id, at: now)
            total += client.hourlyRate.earned(seconds: seconds).amount
        }
        return total > 0 ? [Money(total, currency: settings.defaultCurrency)] : []
    }
}
