import SwiftUI
import TallyCore

/// Saves tracked time as CSV for a spreadsheet or an accountant.
public struct ExportView: View {
    @ObservedObject var model: AppModel
    @State private var draft = ExportDraft()
    @State private var problem: String?

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            Form {
                Picker("Period", selection: $draft.period) {
                    ForEach(PeriodChoice.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Client", selection: $draft.clientID) {
                    Text("All Clients").tag(UUID?.none)
                    ForEach(model.ledger.clients) { Text($0.name).tag(UUID?.some($0.id)) }
                }
                Toggle("Split sessions at midnight", isOn: $draft.options.splitAtMidnight)
                Toggle("Use billing rounding", isOn: $draft.options.applyRounding)
                Toggle("Excel compatible", isOn: $draft.options.excelCompatible)
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
        problem = model.exportCSV(draft, choose: SavePanel.choose).problem
    }
}
