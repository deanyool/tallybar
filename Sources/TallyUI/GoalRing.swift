import SwiftUI
import TallyCore

/// The weekly goal as a ring that fills up.
public struct GoalRing: View {
    let goal: WeeklyGoal
    var lineWidth: CGFloat = 6

    public init(goal: WeeklyGoal, lineWidth: CGFloat = 6) {
        self.goal = goal
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: goal.fraction)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(goal.isMet ? "✓" : "\(goal.percent)%")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .accessibilityElement()
        .accessibilityLabel("Weekly goal")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        goal.isMet
            ? "Goal met, \(goal.percent) percent"
            : "\(goal.percent) percent, \(DurationFormat.words(goal.remainingSeconds)) to go"
    }
}
