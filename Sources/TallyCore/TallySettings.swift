import Foundation

public struct TallySettings: Codable, Equatable, Sendable {
    /// Hours per week the goal ring counts toward. 0 hides the ring.
    public var weeklyGoalHours: Double = 30
    /// Sessions shorter than this are treated as misclicks and dropped.
    public var minimumEntrySeconds: Int = 10
    public var defaultCurrency: String = "USD"

    public init() {}
}
