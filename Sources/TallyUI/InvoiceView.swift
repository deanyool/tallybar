import AppKit
import SwiftUI
import TallyCore

/// Builds an invoice from tracked time and saves it as a PDF.
public struct InvoiceView: View {
    @ObservedObject var model: AppModel
    @State private var draft: InvoiceDraft
    @State private var problem: String?

    public init(model: AppModel) {
        self.model = model
        _draft = State(initialValue: model.newInvoiceDraft())
    }

    public var body: some View {
        VStack(spacing: 0) {
            Form {
                Picker("Client", selection: $draft.clientID) {
                    ForEach(model.ledger.clients) { Text($0.name).tag(UUID?.some($0.id)) }
                }
                Picker("Quick range", selection: quickRange) {
                    Text("Custom").tag(PeriodChoice?.none)
                    ForEach(PeriodChoice.allCases) { Text($0.rawValue).tag(PeriodChoice?.some($0)) }
                }
                DatePicker("From", selection: $draft.start, displayedComponents: .date)
                DatePicker("Through", selection: $draft.end, displayedComponents: .date)
                TextField("Invoice number", text: $draft.number)
                Picker("Lines", selection: $draft.grouping) {
                    Text("One per day").tag(InvoiceGrouping.day)
                    Text("One per entry").tag(InvoiceGrouping.entry)
                    Text("Single total").tag(InvoiceGrouping.total)
                }
                TextField("Tax %", value: $draft.taxPercent, format: .number)
                TextField("Notes", text: $draft.notes, axis: .vertical)
                    .lineLimit(2...4)
            }
            .formStyle(.grouped)
            Divider()
            footer
                .padding(14)
        }
        .frame(width: 460, height: 540)
    }

    private var preview: Result<Invoice, Error> {
        model.invoicePreview(draft)
    }

    /// Picking a range fills in the dates. Editing the dates does not touch this control,
    /// it simply shows no selection unless the dates match a choice.
    private var quickRange: Binding<PeriodChoice?> {
        Binding(
            get: { draft.matchingChoice(at: model.now, calendar: model.calendar) },
            set: { choice in
                guard let choice else { return }
                draft.apply(choice, at: model.now, calendar: model.calendar)
            }
        )
    }

    @ViewBuilder private var footer: some View {
        HStack(alignment: .firstTextBaseline) {
            switch preview {
            case .success(let invoice):
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.text(for: invoice.total))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    Text("\(DurationFormat.decimalHours(invoice.billableSeconds)) hours on \(invoice.lines.count) lines")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .failure(let error):
                Text(String(describing: error))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let problem {
                Text(problem)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Button("Save PDF…", action: save)
                .keyboardShortcut(.defaultAction)
                .disabled((try? preview.get()) == nil)
        }
    }

    private func save() {
        problem = model.saveInvoice(&draft, choose: SavePanel.choose) { NSWorkspace.shared.open($0) }.problem
    }
}
