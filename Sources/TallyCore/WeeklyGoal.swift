import Foundation

/// Progress toward the weekly goal ring.
public struct WeeklyGoal: Equatable, Sendable {
    public var trackedSeconds: Int
    public var goalHours: Double

    public init(trackedSeconds: Int, goalHours: Double) {
        self.trackedSeconds = trackedSeconds
        self.goalHours = goalHours
    }

    public var isEnabled: Bool {
        goalHours > 0
    }

    /// 0 to 1 for the ring. It stops at 1, a full ring is the reward.
    public var fraction: Double {
        min(1, Double(trackedSeconds) / (goalHours * 3600))
    }

    public var isMet: Bool {
        isEnabled && fraction >= 1
    }

    public var remainingSeconds: Int {
        guard isEnabled else { return 0 }
        return max(0, Int((goalHours * 3600).rounded()) - trackedSeconds)
    }

    /// Whole-number percent, not capped, so the label can say "112%".
    public var percent: Int {
        Int((Double(trackedSeconds) / (goalHours * 3600) * 100).rounded())
    }
}

public extension Ledger {
    func weeklyGoal(at now: Date, calendar: Calendar) -> WeeklyGoal {
        let week = calendar.weekInterval(containing: now)
        return WeeklyGoal(
            trackedSeconds: seconds(in: week, at: now),
            goalHours: settings.weeklyGoalHours
        )
    }
}
