import Carbon.HIToolbox
import Foundation
import TallyCore

/// A system-wide shortcut through Carbon's `RegisterEventHotKey`, which is still the
/// supported way to do this. Unlike an event tap it needs no Accessibility permission.
@MainActor
public final class GlobalHotKey {
    private static let signature: OSType = 0x54_4C_59_42 // "TLYB"

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var action: (() -> Void)?

    public init() {}

    /// Replaces any current registration. Returns false when the system refuses the
    /// combination, usually because another app already owns it.
    @discardableResult
    public func register(_ combo: HotKeyCombo, action: @escaping () -> Void) -> Bool {
        unregister()
        guard installHandler() else { return false }
        let identifier = EventHotKeyID(signature: GlobalHotKey.signature, id: 1)
        let status = RegisterEventHotKey(
            combo.keyCode, combo.carbonModifiers, identifier,
            GetEventDispatcherTarget(), 0, &hotKeyRef
        )
        guard status == noErr else {
            hotKeyRef = nil
            return false
        }
        self.action = action
        return true
    }

    public func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
        action = nil
    }

    private func installHandler() -> Bool {
        guard handlerRef == nil else { return true }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, context in
                guard let event, let context else { return OSStatus(eventNotHandledErr) }
                var identifier = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier
                )
                guard identifier.signature == GlobalHotKey.signature else { return OSStatus(eventNotHandledErr) }
                let owner = Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue()
                // Carbon delivers hot keys on the main thread.
                MainActor.assumeIsolated { owner.action?() }
                return noErr
            },
            1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef
        )
        return status == noErr
    }
}
