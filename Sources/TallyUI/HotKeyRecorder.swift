import AppKit
import SwiftUI
import TallyCore

/// Click, press a shortcut, done. Escape cancels and Delete clears it.
struct HotKeyRecorder: View {
    @Binding var combo: HotKeyCombo?
    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var rejected = false

    var body: some View {
        HStack(spacing: 6) {
            Button(title, action: toggleRecording)
                .monospaced()
                .accessibilityLabel("Global shortcut")
                .accessibilityValue(combo?.displayString ?? "none")
            if combo != nil, !isRecording {
                Button {
                    combo = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Clear shortcut")
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private var title: String {
        if rejected { return "Add ⌘, ⌃ or ⌥" }
        if isRecording { return "Press a shortcut…" }
        return combo?.displayString ?? "None"
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        rejected = false
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isRecording = false
    }

    private func handle(_ event: NSEvent) {
        switch event.keyCode {
        case 53: // Escape
            stopRecording()
        case 51, 117: // Delete, Forward Delete
            combo = nil
            stopRecording()
        default:
            let candidate = HotKeyCombo(keyCode: UInt32(event.keyCode), modifiers: event.modifierFlags.hotKeyModifiers)
            if candidate.isValid {
                combo = candidate
                rejected = false
                stopRecording()
            } else {
                rejected = true
            }
        }
    }
}

private extension NSEvent.ModifierFlags {
    var hotKeyModifiers: HotKeyCombo.Modifiers {
        var result: HotKeyCombo.Modifiers = []
        if contains(.control) { result.insert(.control) }
        if contains(.option) { result.insert(.option) }
        if contains(.shift) { result.insert(.shift) }
        if contains(.command) { result.insert(.command) }
        return result
    }
}
