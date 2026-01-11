import SwiftUI
import TallyCore

/// Every entry by day, with editing. This is where a forgotten timer gets corrected.
public struct TimesheetView: View {
    @ObservedObject var model: AppModel
    @State private var period: PeriodChoice
    @State private var clientFilter: UUID?
    @State private var editing: TimeEntry?
    @State private var isAdding = false

    public init(model: AppModel, period: PeriodChoice = .thisWeek) {
        self.model = model
        _period = State(initialValue: period)
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(12)
            Divider()
            if days.isEmpty {
                ContentUnavailableView("No time tracked", systemImage: "clock", description: Text("Nothing in this period yet."))
            } else {
                List {
                    ForEach(days) { day in
                        Section {
                            ForEach(day.rows) { row in
                                TimesheetRowView(model: model, row: row, edit: { editing = row.entry })
                            }
                        } header: {
                            dayHeader(day)
                        }
                    }
                }
                .listStyle(.inset)
            }
            Divider()
            summary
                .padding(12)
        }
        .frame(minWidth: 620, minHeight: 440)
        .sheet(item: $editing) { entry in
            EntryEditor(model: model, entry: entry, isNew: false)
        }
        .sheet(isPresented: $isAdding) {
            EntryEditor(model: model, entry: newEntry, isNew: true)
        }
    }

    private var interval: DateInterval {
        period.interval(at: model.now, calendar: model.calendar)
    }

    private var days: [TimesheetDay] {
        model.ledger.timesheet(in: interval, clientID: clientFilter, calendar: model.calendar)
    }

    private var newEntry: TimeEntry {
        let end = model.now.wholeSecond
        return TimeEntry(
            clientID: clientFilter ?? model.ledger.activeClients.first?.id ?? UUID(),
            start: end.addingTimeInterval(-3600),
            end: end
        )
    }

    private var toolbar: some View {
        HStack {
            Picker("Period", selection: $period) {
                ForEach(PeriodChoice.allCases) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden()
            .frame(width: 140)
            Picker("Client", selection: $clientFilter) {
                Text("All Clients").tag(UUID?.none)
                ForEach(model.ledger.clients) { Text($0.name).tag(UUID?.some($0.id)) }
            }
            .labelsHidden()
            .frame(width: 180)
            Spacer()
            Button {
                isAdding = true
            } label: {
                Label("Add Entry", systemImage: "plus")
            }
            .disabled(model.ledger.activeClients.isEmpty)
        }
    }

    private func dayHeader(_ day: TimesheetDay) -> some View {
        HStack {
            Text(day.day.formatted(Date.FormatStyle(date: .complete, time: .omitted, timeZone: model.timeZone)))
            Spacer()
            Text(DurationFormat.clock(day.seconds))
                .monospacedDigit()
        }
    }

    private var summary: some View {
        let seconds = days.reduce(0) { $0 + $1.seconds }
        return HStack {
            Text("Total")
                .foregroundStyle(.secondary)
            Spacer()
            Text(DurationFormat.clock(seconds))
                .font(.headline)
                .monospacedDigit()
        }
    }
}

private struct TimesheetRowView: View {
    @ObservedObject var model: AppModel
    let row: TimesheetRow
    let edit: () -> Void
    @State private var showProblem: String?

    var body: some View {
        HStack(spacing: 10) {
            if let client = client {
                ClientDot(client: client)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(client?.name ?? "Unknown client")
                if !row.entry.note.isEmpty {
                    Text(row.entry.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(timeRange)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Text(DurationFormat.clock(row.seconds))
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: edit)
        .contextMenu {
            Button("Edit…", action: edit)
            Button("Delete", role: .destructive, action: delete)
        }
        .alert("Can't change this entry", isPresented: isShowingProblem, presenting: showProblem) { _ in
            Button("OK", role: .cancel) {}
        } message: { Text($0) }
    }

    private var client: Client? {
        model.ledger.client(id: row.entry.clientID)
    }

    private var isShowingProblem: Binding<Bool> {
        Binding(
            get: { showProblem != nil },
            set: { if !$0 { showProblem = nil } }
        )
    }

    private func delete() {
        do {
            try model.update { try $0.deleteEntry(id: row.entry.id) }
        } catch {
            showProblem = String(describing: error)
        }
    }

    private var timeRange: String {
        let style = Date.FormatStyle(date: .omitted, time: .shortened, timeZone: model.timeZone)
        let start = row.continuesFromPreviousDay ? "(cont.)" : row.slice.start.formatted(style)
        let end = row.continuesToNextDay ? "(next day)" : row.slice.end.formatted(style)
        return "\(start) to \(end)"
    }
}
