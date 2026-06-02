import SwiftUI
import TallyCore

/// The question asked when someone comes back: was that time work or not?
public struct IdlePromptView: View {
    let away: AwayPeriod
    let clientName: String
    let timeZone: TimeZone
    let answer: (AwayDecision) -> Void

    public init(away: AwayPeriod, clientName: String, timeZone: TimeZone = .current, answer: @escaping (AwayDecision) -> Void) {
        self.away = away
        self.clientName = clientName
        self.timeZone = timeZone
        self.answer = answer
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("You were away \(DurationFormat.words(away.seconds))")
                        .font(.headline)
                    Text("Since \(sinceText), while tracking \(clientName).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Button("Discard and Stop") { answer(.discardAndStop) }
                Spacer()
                Button("Discard") { answer(.discard) }
                Button("Keep") { answer(.keep) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 380)
    }

    private var sinceText: String {
        away.start.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: timeZone))
    }
}
