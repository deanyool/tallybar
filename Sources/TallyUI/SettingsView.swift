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
