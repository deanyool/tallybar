import SwiftUI
import TallyCore

/// The settings window: general behavior, clients, and invoice details.
public struct SettingsView: View {
    @ObservedObject var model: AppModel
    let launchAtLogin: LaunchAtLoginControl

    public init(model: AppModel, launchAtLogin: LaunchAtLoginControl = .system) {
        self.model = model
        self.launchAtLogin = launchAtLogin
    }

    public var body: some View {
        TabView {
            GeneralSettingsView(model: model, launchAtLogin: launchAtLogin)
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
    let launchAtLogin: LaunchAtLoginControl
    @State private var launch = LaunchAtLoginState()

    public init(model: AppModel, launchAtLogin: LaunchAtLoginControl) {
        self.model = model
        self.launchAtLogin = launchAtLogin
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
            Section("Shortcut") {
                LabeledContent("Start or stop") {
                    HotKeyRecorder(combo: model.binding(\.hotKey))
                }
            }
            Section("Startup") {
                Toggle("Launch at login", isOn: launchBinding)
                    .disabled(!launchAtLogin.isAvailable)
                if !launchAtLogin.isAvailable {
                    Text(LaunchAtLoginState.unavailableMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let problem = launch.problem {
                    Text(problem)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { launch.refresh(using: launchAtLogin) }
    }

    private var launchBinding: Binding<Bool> {
        Binding(
            get: { launch.isOn },
            set: { launch.set($0, using: launchAtLogin) }
        )
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
                    .disabled(!model.canAddClient(name: newName, hourlyRate: newRate))
            }
            let archived = model.archivedClients
            if !archived.isEmpty {
                Section("Archived") {
                    ForEach(archived) { client in
                        LabeledContent(client.name) {
                            Button("Restore") {
                                model.restoreClient(id: client.id)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func add() {
        if model.addClient(name: newName, hourlyRate: newRate) != nil {
            newName = ""
        }
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
            TextField("Currency", text: currencyBinding)
            TextField("Billing address", text: field(\.billingAddress), axis: .vertical)
                .lineLimit(2...4)
            Button("Archive") {
                model.archiveClient(id: client.id)
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
                MainActor.assumeIsolated { model.editClient(id: client.id) { $0[keyPath: path] = value } }
            }
        )
    }

    private var amountBinding: Binding<Decimal> {
        Binding(
            get: { client.hourlyRate.amount },
            set: { [client, model] value in
                MainActor.assumeIsolated { model.editClient(id: client.id) { $0.hourlyRate.amount = value } }
            }
        )
    }

    private var currencyBinding: Binding<String> {
        Binding(
            get: { client.hourlyRate.currency },
            set: { [client, model] value in
                MainActor.assumeIsolated { model.editClient(id: client.id) { $0.hourlyRate.currency = value } }
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
                Picker("Round time to", selection: model.binding(\.billingRounding.incrementMinutes)) {
                    Text("Exact time").tag(0)
                    ForEach([1, 5, 6, 10, 15, 30], id: \.self) { Text("\($0) minutes").tag($0) }
                }
                Picker("Rounding", selection: model.binding(\.billingRounding.mode)) {
                    Text("Nearest").tag(BillingRounding.Mode.nearest)
                    Text("Always up").tag(BillingRounding.Mode.up)
                }
                .disabled(model.ledger.settings.billingRounding.incrementMinutes == 0)
                TextField("Default tax %", value: model.binding(\.defaultTaxPercent), format: .number)
                Stepper(
                    "Payment terms: \(model.ledger.settings.paymentTermsDays) days",
                    value: model.binding(\.paymentTermsDays),
                    in: 0...120
                )
                TextField("Invoice prefix", text: model.binding(\.invoicePrefix))
                Picker("Page size", selection: model.binding(\.invoicePageSize)) {
                    Text("US Letter").tag(InvoicePageSize.letter)
                    Text("A4").tag(InvoicePageSize.a4)
                }
            }
        }
        .formStyle(.grouped)
    }
}
