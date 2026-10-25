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

    @Test func recorderCancelsClearsRecordsAndRejects() {
        #expect(HotKeyRecording.interpret(keyCode: 53, modifiers: [.command]) == .cancel)
        #expect(HotKeyRecording.interpret(keyCode: 51, modifiers: []) == .clear)
        #expect(HotKeyRecording.interpret(keyCode: 117, modifiers: []) == .clear)
        #expect(HotKeyRecording.interpret(keyCode: 17, modifiers: [.shift]) == .reject)
        #expect(HotKeyRecording.interpret(keyCode: 200, modifiers: [.command]) == .reject)
        let combo = HotKeyCombo(keyCode: 49, modifiers: [.option, .command])
        #expect(HotKeyRecording.interpret(keyCode: 49, modifiers: [.option, .command]) == .record(combo))
    }
}
