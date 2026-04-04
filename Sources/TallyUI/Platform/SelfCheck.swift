import AppKit
import Foundation
import ServiceManagement
import TallyCore

/// `TallyBar --self-check`: exercises the parts of the app that touch macOS and prints a
/// report. A release can be smoke tested from a script without clicking anything, and
/// the check changes nothing on the system.
@MainActor
public enum SelfCheck {
    public struct Report: Codable {
        public var version: String
        public var isAppBundle: Bool
        public var hotKeyRegistered: Bool
        public var hotKeyHandlerFired: Bool
        public var idleSeconds: Double
        public var launchAtLoginStatus: String
        public var dataFile: String
        public var ok: Bool
    }

    public static func run(combo: HotKeyCombo = HotKeyCombo(keyCode: 111, modifiers: [.control, .option, .shift])) -> Report {
        _ = NSApplication.shared
        var fired = false
        let hotKey = GlobalHotKey()
        let registered = hotKey.register(combo) { fired = true }
        let dispatched = registered && hotKey.simulatePress()
        hotKey.unregister()
        let idle = SystemIdle.seconds
        return Report(
            version: TallyVersion.current,
            isAppBundle: Bundle.main.bundleURL.pathExtension == "app",
            hotKeyRegistered: registered,
            hotKeyHandlerFired: fired,
            idleSeconds: idle,
            launchAtLoginStatus: describe(SMAppService.mainApp.status),
            dataFile: AppController.storeURL.path,
            ok: registered && dispatched && fired && idle >= 0
        )
    }

    private static func describe(_ status: SMAppService.Status) -> String {
        switch status {
        case .notRegistered: return "notRegistered"
        case .enabled: return "enabled"
        case .requiresApproval: return "requiresApproval"
        case .notFound: return "notFound"
        @unknown default: return "unknown"
        }
    }
}
