import SwiftUI
import TallyCore

/// The buttons in the panel that lead out of it. Closures, so the panel does not know
/// how windows are opened and can be rendered on its own.
public struct MenuActions {
    public var openTimesheet: () -> Void
    public var openInvoice: () -> Void
    public var openExport: () -> Void
    public var openSettings: () -> Void
    public var quit: () -> Void

    public init(
        openTimesheet: @escaping () -> Void = {},
        openInvoice: @escaping () -> Void = {},
        openExport: @escaping () -> Void = {},
        openSettings: @escaping () -> Void = {},
        quit: @escaping () -> Void = {}
    ) {
        self.openTimesheet = openTimesheet
        self.openInvoice = openInvoice
        self.openExport = openExport
        self.openSettings = openSettings
        self.quit = quit
    }
}

/// The popover under the menu bar icon.
public struct MenuPanel: View {
    @ObservedObject var model: AppModel
    let actions: MenuActions

    public init(model: AppModel, actions: MenuActions) {
        self.model = model
        self.actions = actions
    }

    public var body: some View {
        VStack(spacing: 0) {
            SummaryHeader(model: model)
                .padding(14)
            if let running = model.ledger.running, let client = model.runningClient {
                Divider()
                RunningCard(model: model, running: running, client: client)
                    .padding(12)
            }
            Divider()
            clientList
            Divider()
            footer
        }
        .frame(width: Theme.panelWidth)
    }

    @ViewBuilder private var clientList: some View {
        if model.ledger.activeClients.isEmpty {
            VStack(spacing: 8) {
                Text("No clients yet")
                    .font(.headline)
                Text("Add a client and an hourly rate to start tracking.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Add a Client", action: actions.openSettings)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 2) {
                ForEach(model.ledger.activeClients) { client in
                    ClientRow(
                        client: client,
                        rateText: "\(model.text(for: client.hourlyRate))/h",
                        todaySeconds: model.todaySeconds(clientID: client.id),
                        isRunning: model.ledger.running?.clientID == client.id,
                        toggle: { model.toggle(clientID: client.id) }
                    )
                }
            }
            .padding(6)
        }
    }

    private var footer: some View {
        HStack(spacing: 2) {
            FooterButton(title: "Timesheet", symbol: "list.bullet.rectangle", action: actions.openTimesheet)
            FooterButton(title: "Invoice", symbol: "doc.text", action: actions.openInvoice)
            FooterButton(title: "Export", symbol: "square.and.arrow.up", action: actions.openExport)
            Spacer()
            FooterButton(title: "Settings", symbol: "gearshape", action: actions.openSettings)
            FooterButton(title: "Quit", symbol: "power", action: actions.quit)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}

private struct FooterButton: View {
    let title: String
    let symbol: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 30, height: 26)
                .background(isHovered ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(title)
        .onHover { isHovered = $0 }
    }
}

/// Goal ring, week total, today's total and earnings.
struct SummaryHeader: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 14) {
            if model.weeklyGoal.isEnabled {
                GoalRing(goal: model.weeklyGoal)
                    .frame(width: 52, height: 52)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("This week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(DurationFormat.clock(model.weekSeconds))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    if model.weeklyGoal.isEnabled {
                        Text("of \(model.ledger.settings.weeklyGoalHours.formatted())h")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(todayLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
        }
    }

    private var todayLine: String {
        let earned = model.text(for: model.todayEarnings)
        let time = "Today \(DurationFormat.clock(model.todaySeconds))"
        return earned.isEmpty ? time : "\(time) · \(earned)"
    }
}

/// The running timer with its stop button and note.
struct RunningCard: View {
    @ObservedObject var model: AppModel
    let running: RunningSession
    let client: Client

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ClientDot(client: client)
                Text(client.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Spacer()
                if model.hasLiveClock {
                    TimelineView(.periodic(from: running.start, by: 1)) { context in
                        ElapsedText(seconds: running.elapsed(at: context.date))
                    }
                } else {
                    ElapsedText(seconds: running.elapsed(at: model.now))
                }
                Button {
                    model.toggle(clientID: client.id)
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11))
                        .frame(width: 26, height: 26)
                        .foregroundStyle(.white)
                        .background(Color.red.opacity(0.85), in: Circle())
                }
                .buttonStyle(.plain)
            }
            TextField("What are you working on?", text: noteBinding)
                .textFieldStyle(.plain)
                .font(.caption)
        }
        .padding(10)
        .background(Theme.color(for: client).opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { running.note },
            set: { [model] note in MainActor.assumeIsolated { model.setRunningNote(note) } }
        )
    }
}

private struct ElapsedText: View {
    let seconds: Int

    var body: some View {
        Text(DurationFormat.clockWithSeconds(seconds))
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .monospacedDigit()
    }
}
