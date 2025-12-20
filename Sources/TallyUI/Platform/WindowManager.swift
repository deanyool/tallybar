import AppKit
import SwiftUI

/// Opens the app's ordinary windows by hand. A menu bar app has no Dock icon and no
/// window at launch, so each window is created on first use and has to activate the
/// app itself or it would open behind whatever is in front.
@MainActor
public final class WindowManager {
    private var windows: [String: NSWindow] = [:]

    public init() {}

    public func show<Content: View>(id: String, title: String, @ViewBuilder content: () -> Content) {
        let window = windows[id] ?? makeWindow(title: title, content: content())
        windows[id] = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    public func close(id: String) {
        windows[id]?.close()
        windows[id] = nil
    }

    public var openWindowIDs: [String] {
        windows.filter(\.value.isVisible).map(\.key).sorted()
    }

    private func makeWindow<Content: View>(title: String, content: Content) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.title = title
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
