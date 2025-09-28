import SwiftUI
import TallyCore

class Tracker: ObservableObject {
    @Published var log = TimeLog.load()

    func toggle(_ client: String) {
        log.toggle(client)
        log.save()
    }
}

@main
struct TallyBarApp: App {
    @StateObject var tracker = Tracker()

    var body: some Scene {
        MenuBarExtra("Tally", systemImage: "timer") {
            ForEach(tracker.log.clients, id: \.self) { client in
                Button(client + (tracker.log.current == client ? " (running)" : "")) {
                    tracker.toggle(client)
                }
            }
            Divider()
            Text("Today: \(Int(tracker.log.todayTotal / 60)) min, $\(String(format: "%.2f", tracker.log.todayEarned))")
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}
