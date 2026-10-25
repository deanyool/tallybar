import Foundation

/// A global shortcut as virtual key code plus modifiers. Lives in the core so the
/// display string and validation are testable without Carbon.
public struct HotKeyCombo: Hashable, Codable, Sendable {
    public struct Modifiers: OptionSet, Hashable, Codable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)
    }

    public var keyCode: UInt32
    public var modifiers: Modifiers

    public init(keyCode: UInt32, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Control-Option-Command-T.
    public static let standard = HotKeyCombo(keyCode: 17, modifiers: [.control, .option, .command])

    /// Shift alone would swallow normal typing, so a real modifier is required.
    public var isValid: Bool {
        !modifiers.isDisjoint(with: [.control, .option, .command])
            && HotKeyCombo.keyNames[keyCode] != nil
    }

    /// The modifier mask `RegisterEventHotKey` expects (Carbon's cmdKey and friends).
    public var carbonModifiers: UInt32 {
        var flags: UInt32 = 0
        if modifiers.contains(.command) { flags |= 1 << 8 }
        if modifiers.contains(.shift) { flags |= 1 << 9 }
        if modifiers.contains(.option) { flags |= 1 << 11 }
        if modifiers.contains(.control) { flags |= 1 << 12 }
        return flags
    }

    /// Standard Apple order: "⌃⌥⇧⌘T".
    public var displayString: String {
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        return text + (HotKeyCombo.keyNames[keyCode] ?? "Key \(keyCode)")
    }

    /// ANSI virtual key codes for the keys a shortcut can reasonably use.
    static let keyNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9", 26: "7", 28: "8", 29: "0",
        31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
        49: "Space",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
        109: "F10", 111: "F12", 118: "F4", 120: "F2", 122: "F1"
    ]
}

/// What the shortcut recorder does with one key press. Escape cancels, Delete clears,
/// anything else becomes the shortcut if it is usable.
public enum HotKeyRecording: Equatable, Sendable {
    case cancel
    case clear
    case record(HotKeyCombo)
    /// The key needs Command, Control or Option, or it is not one a shortcut can use.
    case reject

    static let escape: UInt32 = 53
    static let delete: UInt32 = 51
    static let forwardDelete: UInt32 = 117

    public static func interpret(keyCode: UInt32, modifiers: HotKeyCombo.Modifiers) -> HotKeyRecording {
        switch keyCode {
        case escape:
            return .cancel
        case delete, forwardDelete:
            return .clear
        default:
            let candidate = HotKeyCombo(keyCode: keyCode, modifiers: modifiers)
            return candidate.isValid ? .record(candidate) : .reject
        }
    }
}
