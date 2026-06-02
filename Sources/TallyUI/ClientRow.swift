import SwiftUI
import TallyCore

/// One client in the menu. The whole row is the button, so tracking takes one click.
struct ClientRow: View {
    let client: Client
    let rateText: String
    let todaySeconds: Int
    let isRunning: Bool
    let toggle: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 8) {
                ClientDot(client: client)
                VStack(alignment: .leading, spacing: 1) {
                    Text(client.name)
                        .font(.system(size: 13))
                        .lineLimit(1)
                    Text(rateText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if todaySeconds > 0 {
                    Text(DurationFormat.clock(todaySeconds))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Image(systemName: isRunning ? "stop.circle.fill" : "play.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isRunning ? Color.red.opacity(0.85) : Theme.color(for: client))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isHovered ? Color.primary.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(isRunning ? "Stops the timer" : "Starts the timer")
    }

    private var accessibilityText: String {
        var text = client.name
        if todaySeconds > 0 {
            text += ", \(DurationFormat.words(todaySeconds)) today"
        }
        return isRunning ? "\(text), tracking" : text
    }
}
