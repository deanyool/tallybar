import AppKit
import SwiftUI
import TallyCore
import UniformTypeIdentifiers

/// Saves tracked time as CSV for a spreadsheet or an accountant.
public struct ExportView: View {
    @ObservedObject var model: AppModel
    @State private var period: PeriodChoice = .thisMonth
    @State private var clientID: UUID?
    @State private var options = CSVOptions()
    @State private var problem: String?

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            Form {
                Picker("Period", selection: $period) {
                    ForEach(PeriodChoice.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Client", selection: $clientID) {
                    Text("All Clients").tag(UUID?.none)
                    ForEach(model.ledger.clients) { Text($0.name).tag(UUID?.some($0.id)) }
                }
                Toggle("Split sessions at midnight", isOn: $options.splitAtMidnight)
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                if let problem {
                    Text(problem)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Spacer()
                Button("Save CSV…", action: save)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(14)
        }
        .frame(width: 400, height: 320)
    }

    private func save() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "tallybar-\(period.rawValue.lowercased().replacingOccurrences(of: " ", with: "-")).csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let interval = period.interval(at: model.now, calendar: model.calendar)
            try model.saveCSV(in: interval, clientID: clientID, options: options, to: url)
            problem = nil
        } catch {
            problem = String(describing: error)
        }
    }
}
