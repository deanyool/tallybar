import Foundation
import SwiftUI
import TallyCore
import TallyUI

@main
struct TallyBarEntry {
    @MainActor
    static func main() {
        // macOS adds -psn_... when the app is opened from Finder on some versions.
        let arguments = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-psn_") }
        switch arguments.first {
        case nil:
            TallyBarApp.main()
        case "--self-check":
            runSelfCheck()
        case "--version":
            print("TallyBar \(TallyVersion.current)")
        case "--help", "-h":
            print(usage)
        case let other?:
            FileHandle.standardError.write(Data("TallyBar: unknown option \(other)\n\n\(usage)\n".utf8))
            exit(2)
        }
    }

    static let usage = """
        TallyBar \(TallyVersion.current), a menu bar time tracker.

        Usage: TallyBar [--self-check | --version | --help]

        With no options it starts in the menu bar. Usually you open TallyBar.app instead.

          --self-check   Check the hotkey, idle clock and login item, print a JSON report
          --version      Print the version
          --help         Show this help

        TALLYBAR_DATA_DIR=<folder> keeps ledger.json there instead of
        ~/Library/Application Support/TallyBar.
        """

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
