import Foundation

public extension Ledger {
    /// Quick CSV of everything in `interval`.
    func csv(in interval: DateInterval, clientID: UUID? = nil, calendar: Calendar) -> String {
        var out = "date,start,end,hours,client,note,amount\n"
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = calendar.timeZone
        for entry in entries where interval.contains(entry.start) {
            if let clientID, entry.clientID != clientID { continue }
            guard let client = client(id: entry.clientID) else { continue }
            let hours = DurationFormat.decimalHours(entry.seconds)
            let amount = client.hourlyRate.earned(seconds: entry.seconds).plainString
            let day = formatter.string(from: entry.start).prefix(10)
            out += "\(day),\(formatter.string(from: entry.start)),\(formatter.string(from: entry.end))"
            out += ",\(hours),\(client.name),\(entry.note),\(amount)\n"
        }
        return out
    }
}
