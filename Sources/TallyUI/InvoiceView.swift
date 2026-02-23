import AppKit
import SwiftUI
import TallyCore
import UniformTypeIdentifiers

/// Builds an invoice from tracked time and saves it as a PDF.
public struct InvoiceView: View {
    @ObservedObject var model: AppModel
    @State private var clientID: UUID?
    @State private var start: Date
    @State private var end: Date
    @State private var number: String
    @State private var grouping: InvoiceGrouping = .day
    @State private var taxPercent: Decimal
    @State private var notes = ""
    @State private var problem: String?

    public init(model: AppModel) {
        self.model = model
        let month = PeriodChoice.lastMonth.interval(at: model.now, calendar: model.calendar)
        _clientID = State(initialValue: model.ledger.activeClients.first?.id)
        _start = State(initialValue: month.start)
        _end = State(initialValue: month.end.addingTimeInterval(-1))
        _number = State(initialValue: model.ledger.suggestedInvoiceNumber)
        _taxPercent = State(initialValue: model.ledger.settings.defaultTaxPercent)
    }

    public var body: some View {
        VStack(spacing: 0) {
            Form {
                Picker("Client", selection: $clientID) {
                    ForEach(model.ledger.clients) { Text($0.name).tag(UUID?.some($0.id)) }
                }
                Picker("Quick range", selection: quickRange) {
                    Text("Custom").tag(PeriodChoice?.none)
                    ForEach(PeriodChoice.allCases) { Text($0.rawValue).tag(PeriodChoice?.some($0)) }
                }
                DatePicker("From", selection: $start, displayedComponents: .date)
                DatePicker("Through", selection: $end, displayedComponents: .date)
                TextField("Invoice number", text: $number)
                Picker("Lines", selection: $grouping) {
                    Text("One per day").tag(InvoiceGrouping.day)
                    Text("One per entry").tag(InvoiceGrouping.entry)
                    Text("Single total").tag(InvoiceGrouping.total)
                }
                TextField("Tax %", value: $taxPercent, format: .number)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }
            .formStyle(.grouped)
            Divider()
            footer
                .padding(14)
        }
        .frame(width: 460, height: 540)
    }

    private var request: InvoiceRequest? {
        guard let clientID else { return nil }
        return InvoiceRequest(
            clientID: clientID,
            period: model.calendar.inclusiveDays(from: start, through: end),
            number: number,
            issueDate: model.now,
            grouping: grouping,
            taxPercent: taxPercent,
            notes: notes
        )
    }

    private var preview: Result<Invoice, Error>? {
        guard let request else { return nil }
        return Result { try model.ledger.buildInvoice(request, calendar: model.calendar) }
    }

    /// Picking a range fills in the dates. Editing the dates does not touch this control,
    /// it simply shows no selection unless the dates match a choice.
    private var quickRange: Binding<PeriodChoice?> {
        Binding(
            get: {
                PeriodChoice.allCases.first { choice in
                    let interval = choice.interval(at: model.now, calendar: model.calendar)
                    return model.calendar.isDate(interval.start, inSameDayAs: start)
                        && model.calendar.isDate(interval.end.addingTimeInterval(-1), inSameDayAs: end)
                }
            },
            set: { choice in
                guard let choice else { return }
                let interval = choice.interval(at: model.now, calendar: model.calendar)
                start = interval.start
                end = interval.end.addingTimeInterval(-1)
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
            case nil:
                Text("Choose a client.")
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
                .disabled((try? preview?.get()) == nil)
        }
    }

    private func save() {
        guard let request else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(number).pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.saveInvoice(request, to: url)
            number = model.ledger.suggestedInvoiceNumber
            problem = nil
            NSWorkspace.shared.open(url)
        } catch {
            problem = String(describing: error)
        }
    }
}
