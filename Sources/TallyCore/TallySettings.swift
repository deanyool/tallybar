import Foundation

public struct TallySettings: Codable, Equatable, Sendable {
    /// Hours per week the goal ring counts toward. 0 hides the ring.
    public var weeklyGoalHours: Double = 30
    /// Minutes without input before asking about the time. 0 turns detection off.
    public var idleThresholdMinutes: Int = 5
    /// 1 is Sunday, 2 is Monday, matching `Calendar.firstWeekday`.
    public var firstWeekday: Int = 2
    /// Sessions shorter than this are treated as misclicks and dropped.
    public var minimumEntrySeconds: Int = 10
    public var defaultCurrency: String = "USD"

    public init() {}
}
