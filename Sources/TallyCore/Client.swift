import Foundation

/// Someone you bill. Clients are archived rather than deleted so old entries and
/// invoices keep their names.
public struct Client: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var hourlyRate: Money
    public var colorIndex: Int
    public var billingAddress: String
    public var isArchived: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        hourlyRate: Money,
        colorIndex: Int = 0,
        billingAddress: String = "",
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.hourlyRate = hourlyRate
        self.colorIndex = colorIndex
        self.billingAddress = billingAddress
        self.isArchived = isArchived
    }
}

extension Client: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, hourlyRate, colorIndex, billingAddress, isArchived
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        hourlyRate = try container.decode(Money.self, forKey: .hourlyRate)
        colorIndex = try container.decodeIfPresent(Int.self, forKey: .colorIndex) ?? 0
        billingAddress = try container.decodeIfPresent(String.self, forKey: .billingAddress) ?? ""
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }
}
