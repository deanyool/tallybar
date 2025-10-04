import SwiftUI
import TallyCore

class Tracker: ObservableObject {
    @Published var log = TimeLog.load()
    @Published var now = Date()
    private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.now = Date()
        }
    }

    var label: String {
        guard let startedAt = log.startedAt else { return "" }
        return "\(Int(now.timeIntervalSince(startedAt) / 60))m"
    }

    func toggle(_ client: String) {
        log.toggle(client)
        log.save()
    }
}

@main
struct TallyBarApp: App {
    @StateObject var tracker = Tracker()

    var body: some Scene {
        MenuBarExtra {
            ForEach(tracker.log.clients, id: \.self) { client in
                Button(client + (tracker.log.current == client ? " (running)" : "")) {
                    tracker.toggle(client)
                }
            }
            Divider()
            Text("Today: \(Int(tracker.log.todayTotal / 60)) min, \(tracker.log.todayEarned.formatted())")
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        } label: {
            Image(systemName: "timer")
            Text(tracker.label)
        }
    }
}
