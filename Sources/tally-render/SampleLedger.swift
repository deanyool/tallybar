import Foundation
import TallyCore

/// A made-up freelancer with made-up clients, on fixed dates so renders are repeatable.
enum SampleLedger {
    static let timeZone = TimeZone(identifier: "America/Toronto") ?? .gmt
    static let now = date("2025-11-05T16:12:00")
    static let locale = Locale(identifier: "en_US")

    static func date(_ local: String) -> Date {
        let style = Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day()
            .dateTimeSeparator(.standard).time(includingFractionalSeconds: false)
        return (try? style.parse(local)) ?? Date(timeIntervalSince1970: 0)
    }

    static func make() -> Ledger {
        var ledger = Ledger()
        ledger.settings.weeklyGoalHours = 30
        ledger.settings.business = BusinessProfile(
            name: "Alex Rivera Design",
            address: "120 Example Lane, Suite 4\nToronto, ON M5V 0A1",
            email: "billing@alexrivera.example",
            taxID: "000000000 RT0001",
            paymentInstructions: "Pay by bank transfer within 30 days. Reference the invoice number."
        )
        ledger.settings.defaultTaxPercent = 13
        let lumen = ledger.addClient(name: "Lumen Coffee Roasters", hourlyRate: 120)
        let harbor = ledger.addClient(name: "Harbor & Pine Studio", hourlyRate: 95)
        let tide = ledger.addClient(name: "Tidewater Books", hourlyRate: 85)

        var lumenClient = lumen
        lumenClient.billingAddress = "48 Roastery Road\nHalifax, NS B3H 0A1"
        ledger.updateClient(lumenClient)

        let work: [(Client, String, String, String)] = [
            (lumen, "2025-10-06T09:05:00", "2025-10-06T11:40:00", "Packaging concepts"),
            (harbor, "2025-10-06T13:00:00", "2025-10-06T15:30:00", "Homepage layout"),
            (lumen, "2025-10-07T10:00:00", "2025-10-07T12:15:00", "Packaging concepts"),
            (tide, "2025-10-08T14:00:00", "2025-10-08T15:45:00", "Catalog grid"),
            (lumen, "2025-10-14T09:30:00", "2025-10-14T12:30:00", "Label artwork"),
            (lumen, "2025-10-15T22:30:00", "2025-10-16T00:45:00", "Print proofs"),
            (lumen, "2025-10-21T09:00:00", "2025-10-21T11:30:00", "Label artwork"),
            (lumen, "2025-10-28T13:15:00", "2025-10-28T16:00:00", "Website photography brief"),
            (lumen, "2025-11-03T09:00:00", "2025-11-03T12:10:00", "Holiday campaign"),
            (harbor, "2025-11-03T13:00:00", "2025-11-03T16:30:00", "Case study pages"),
            (tide, "2025-11-04T09:30:00", "2025-11-04T11:45:00", "Catalog grid"),
            (harbor, "2025-11-04T12:30:00", "2025-11-04T17:15:00", "Case study pages"),
            (lumen, "2025-11-04T21:40:00", "2025-11-05T00:20:00", "Holiday campaign"),
            (harbor, "2025-11-05T09:10:00", "2025-11-05T11:25:00", "Design review"),
            (tide, "2025-11-05T13:00:00", "2025-11-05T14:30:00", "Author page")
        ]
        for (client, start, end, note) in work {
            ledger.entries.append(TimeEntry(clientID: client.id, start: date(start), end: date(end), note: note))
        }
        ledger.start(clientID: lumen.id, note: "Holiday campaign landing page", at: date("2025-11-05T14:52:00"))
        return ledger
    }
}
