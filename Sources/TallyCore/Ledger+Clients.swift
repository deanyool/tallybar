import Foundation

public extension Ledger {
    /// Adds a client, cycling through the palette so neighbors get different colors.
    @discardableResult
    mutating func addClient(name: String, hourlyRate: Decimal, currency: String? = nil) -> Client {
        let client = Client(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            hourlyRate: Money(hourlyRate, currency: currency ?? settings.defaultCurrency),
            colorIndex: clients.count
        )
        clients.append(client)
        return client
    }

    mutating func updateClient(_ client: Client) {
        guard let index = clients.firstIndex(where: { $0.id == client.id }) else { return }
        clients[index] = client
    }

    /// Hides a client from the menu. A running session for them is stopped first so the
    /// timer can never tick for someone who is no longer listed.
    mutating func archiveClient(id: UUID, at now: Date) {
        guard let index = clients.firstIndex(where: { $0.id == id }) else { return }
        if running?.clientID == id {
            stop(at: now)
        }
        clients[index].isArchived = true
    }

    mutating func unarchiveClient(id: UUID) {
        guard let index = clients.firstIndex(where: { $0.id == id }) else { return }
        clients[index].isArchived = false
    }
}
