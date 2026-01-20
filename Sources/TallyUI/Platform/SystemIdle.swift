import CoreGraphics
import Foundation

/// Reads how long the machine has gone without input. This asks the window server for
/// a number only. It needs no permissions and sees nothing about what was typed.
public enum SystemIdle {
    public static var seconds: TimeInterval {
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }
}
