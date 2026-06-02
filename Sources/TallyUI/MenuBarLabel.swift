import SwiftUI
import TallyCore

/// What sits in the menu bar: a timer icon, plus the elapsed time while tracking.
public struct MenuBarLabel: View {
    @ObservedObject var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        if let running = model.ledger.running {
            Label {
                Text(DurationFormat.clock(running.elapsed(at: model.now)))
                    .monospacedDigit()
            } icon: {
                Image(systemName: "timer")
            }
            .labelStyle(.titleAndIcon)
            .accessibilityLabel(runningDescription(running))
        } else {
            Image(systemName: "timer")
                .accessibilityLabel("TallyBar, not tracking")
        }
    }

    private func runningDescription(_ running: RunningSession) -> String {
        let elapsed = DurationFormat.words(running.elapsed(at: model.now))
        return "TallyBar, tracking \(model.runningClient?.name ?? "a client"), \(elapsed)"
    }
}
