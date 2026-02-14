import Foundation

/// The "from" block printed on invoices. Stays on this Mac like everything else.
public struct BusinessProfile: Hashable, Sendable {
    public var name: String
    public var address: String
    public var email: String
    public var taxID: String
    public var paymentInstructions: String

    public init(
        name: String = "",
        address: String = "",
        email: String = "",
        taxID: String = "",
        paymentInstructions: String = ""
    ) {
        self.name = name
        self.address = address
        self.email = email
        self.taxID = taxID
        self.paymentInstructions = paymentInstructions
    }
}

extension BusinessProfile: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, address, email, taxID, paymentInstructions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        taxID = try container.decodeIfPresent(String.self, forKey: .taxID) ?? ""
        paymentInstructions = try container.decodeIfPresent(String.self, forKey: .paymentInstructions) ?? ""
    }
}
