import Testing
@testable import TallyCore

@Suite("Hotkey combos")
struct HotKeyComboTests {
    @Test func defaultShortcutReadsInAppleOrder() {
        #expect(HotKeyCombo.standard.displayString == "⌃⌥⌘T")
    }

    @Test func allModifiersMapToCarbonBits() {
        let combo = HotKeyCombo(keyCode: 49, modifiers: [.command, .shift, .option, .control])
        #expect(combo.carbonModifiers == 0x100 | 0x200 | 0x800 | 0x1000)
        #expect(combo.displayString == "⌃⌥⇧⌘Space")
    }

    @Test func shiftAloneIsNotEnough() {
        #expect(!HotKeyCombo(keyCode: 17, modifiers: [.shift]).isValid)
        #expect(!HotKeyCombo(keyCode: 17, modifiers: []).isValid)
        #expect(HotKeyCombo(keyCode: 17, modifiers: [.shift, .command]).isValid)
    }

    @Test func unknownKeysAreRejected() {
        #expect(!HotKeyCombo(keyCode: 200, modifiers: [.command]).isValid)
    }
}
