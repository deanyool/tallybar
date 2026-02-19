import SwiftUI
import TallyCore

/// The settings window: general behavior, clients, and invoice details.
public struct SettingsView: View {
    @ObservedObject var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        TabView {
            GeneralSettingsView(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
            ClientsSettingsView(model: model)
                .tabItem { Label("Clients", systemImage: "person.2") }
            InvoiceSettingsView(model: model)
                .tabItem { Label("Invoices", systemImage: "doc.text") }
        }
        .frame(width: 520, height: 460)
    }
}

/// Goal, idle detection, hotkey and startup.
public struct GeneralSettingsView: View {
    @ObservedObject var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        Form {
            Section("Tracking") {
                LabeledContent("Weekly goal") {
                    HStack {
                        TextField("Hours", value: model.binding(\.weeklyGoalHours), format: .number)
                            .labelsHidden()
                            .frame(width: 60)
                        Text("hours")
                    }
                }
                Picker("Ask when idle for", selection: model.binding(\.idleThresholdMinutes)) {
                    Text("Never").tag(0)
                    ForEach([2, 5, 10, 15, 30], id: \.self) { Text("\($0) minutes").tag($0) }
                }
                Picker("Week starts on", selection: model.binding(\.firstWeekday)) {
                    Text("Sunday").tag(1)
                    Text("Monday").tag(2)
                    Text("Saturday").tag(7)
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// Add, rename, reprice and archive clients.
public struct ClientsSettingsView: View {
    @ObservedObject var model: AppModel
    @State private var newName = ""
    @State private var newRate: Decimal = 100

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        Form {
            Section("Active") {
                ForEach(model.ledger.activeClients) { client in
                    ClientEditorRow(model: model, client: client)
                }
            }
            Section("Add a client") {
                TextField("Name", text: $newName)
                TextField("Hourly rate", value: $newRate, format: .number)
                Button("Add Client", action: add)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            let archived = model.ledger.clients.filter(\.isArchived)
            if !archived.isEmpty {
                Section("Archived") {
                    ForEach(archived) { client in
                        LabeledContent(client.name) {
                            Button("Restore") {
                                model.update { $0.unarchiveClient(id: client.id) }
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func add() {
        model.update { $0.addClient(name: newName, hourlyRate: newRate) }
        newName = ""
    }
}

private struct ClientEditorRow: View {
    @ObservedObject var model: AppModel
    let client: Client
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            TextField("Name", text: field(\.name))
            TextField("Hourly rate", value: amountBinding, format: .number)
            TextField("Billing address", text: field(\.billingAddress), axis: .vertical)
                .lineLimit(2...4)
            Button("Archive") {
                model.update { $0.archiveClient(id: client.id, at: Date()) }
            }
        } label: {
            HStack {
                ClientDot(client: client)
                Text(client.name)
                Spacer()
                Text("\(model.text(for: client.hourlyRate))/h")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func field(_ path: WritableKeyPath<Client, String> & Sendable) -> Binding<String> {
        Binding(
            get: { client[keyPath: path] },
            set: { [client, model] value in
                MainActor.assumeIsolated {
                    var copy = client
                    copy[keyPath: path] = value
                    model.update { $0.updateClient(copy) }
                }
            }
        )
    }

    private var amountBinding: Binding<Decimal> {
        Binding(
            get: { client.hourlyRate.amount },
            set: { [client, model] value in
                MainActor.assumeIsolated {
                    var copy = client
                    copy.hourlyRate.amount = value
                    model.update { $0.updateClient(copy) }
                }
            }
        )
    }
}

/// Details printed on invoices and how billable time is rounded.
public struct InvoiceSettingsView: View {
    @ObservedObject var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        Form {
            Section("Your business") {
                TextField("Name", text: model.binding(\.business.name))
                TextField("Address", text: model.binding(\.business.address), axis: .vertical)
                    .lineLimit(2...4)
                TextField("Email", text: model.binding(\.business.email))
                TextField("Tax ID", text: model.binding(\.business.taxID))
                TextField("Payment instructions", text: model.binding(\.business.paymentInstructions), axis: .vertical)
                    .lineLimit(2...4)
            }
            Section("Billing") {
                TextField("Default tax %", value: model.binding(\.defaultTaxPercent), format: .number)
                Stepper(
                    "Payment terms: \(model.ledger.settings.paymentTermsDays) days",
                    value: model.binding(\.paymentTermsDays),
                    in: 0...120
                )
                TextField("Invoice prefix", text: model.binding(\.invoicePrefix))
                Picker("Page size", selection: model.binding(\.invoicePageSize)) {
                    Text("US Letter").tag(InvoicePageSize.letter)
                }
            }
        }
        .formStyle(.grouped)
    }
}
