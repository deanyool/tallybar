import SwiftUI

// quick prototype, everything in one file for now

struct Entry: Identifiable {
    let id = UUID()
    var client: String
    var start: Date
    var end: Date
}

class Tracker: ObservableObject {
    @Published var clients = ["Client A", "Client B"]
    @Published var entries: [Entry] = []
    @Published var current: String?
    @Published var startedAt: Date?

    func toggle(_ client: String) {
        if let current = current, let startedAt = startedAt {
            entries.append(Entry(client: current, start: startedAt, end: Date()))
        }
        if current == client {
            current = nil
            startedAt = nil
        } else {
            current = client
            startedAt = Date()
        }
    }
}

@main
struct TallyBarApp: App {
    @StateObject var tracker = Tracker()

    var body: some Scene {
        MenuBarExtra("Tally", systemImage: "timer") {
            ForEach(tracker.clients, id: \.self) { client in
                Button(client + (tracker.current == client ? " (running)" : "")) {
                    tracker.toggle(client)
                }
            }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}
