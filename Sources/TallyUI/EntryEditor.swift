import SwiftUI
import TallyCore

/// Adds or corrects an entry by hand.
struct EntryEditor: View {
    @ObservedObject var model: AppModel
    @State var entry: TimeEntry
    let isNew: Bool
    @State private var problem: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isNew ? "Add Entry" : "Edit Entry")
                .font(.headline)
            Form {
                Picker("Client", selection: $entry.clientID) {
                    ForEach(model.ledger.clients) { Text($0.name).tag($0.id) }
                }
                DatePicker("Start", selection: $entry.start)
                DatePicker("End", selection: $entry.end)
                TextField("Note", text: $entry.note)
                LabeledContent("Duration", value: DurationFormat.words(entry.seconds))
            }
            if let problem {
                Text(problem)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 400)
    }

    private func save() {
        do {
            try model.update { try $0.save(entry) }
            dismiss()
        } catch {
            problem = String(describing: error)
        }
    }
}
