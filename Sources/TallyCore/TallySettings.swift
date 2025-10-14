import Foundation

public struct TallySettings: Codable, Equatable, Sendable {
    /// Sessions shorter than this are treated as misclicks and dropped.
    public var minimumEntrySeconds: Int = 10
    public var defaultCurrency: String = "USD"

    public init() {}
}
