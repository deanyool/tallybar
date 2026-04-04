import Foundation
import SwiftUI
import TallyCore
import TallyUI

@main
struct TallyBarEntry {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--self-check") {
            runSelfCheck()
        }
        if CommandLine.arguments.contains("--version") {
            print("TallyBar \(TallyVersion.current)")
            return
        }
        TallyBarApp.main()
    }

    @MainActor
    private static func runSelfCheck() -> Never {
        let report = SelfCheck.run()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if let data = try? encoder.encode(report), let text = String(data: data, encoding: .utf8) {
            print(text)
        }
        exit(report.ok ? 0 : 1)
    }
}

/// The app has one scene, the menu bar item. Other windows are opened on demand by
/// `WindowManager`, so nothing appears at launch.
struct TallyBarApp: App {
    @StateObject private var controller = AppController.live()

    var body: some Scene {
        MenuBarExtra {
            MenuPanel(model: controller.model, actions: controller.menuActions)
        } label: {
            MenuBarLabel(model: controller.model)
        }
        .menuBarExtraStyle(.window)
    }
}
