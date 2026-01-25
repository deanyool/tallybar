import Foundation

/// Decides when someone was away, from periodic samples of "seconds since last input".
/// Pure on purpose: the real input clock and timer live in the app, so every edge case
/// here runs in a test with made-up numbers.
public struct IdleMonitor: Sendable {
    /// Seconds without input before it counts as away. 0 disables detection.
    public var threshold: TimeInterval

    private var awaySince: Date?
    private var lastSample: Date?

    public init(threshold: TimeInterval) {
        self.threshold = threshold
    }

    /// True between the moment the person left and the moment they came back.
    public var isAway: Bool {
        awaySince != nil
    }

    /// Feeds one sample. Returns the away period at the moment the person returns.
    public mutating func sample(now: Date, idleSeconds: TimeInterval, isTracking: Bool) -> AwayPeriod? {
        defer { lastSample = now }
        guard isTracking, threshold > 0 else {
            awaySince = nil
            return nil
        }
        // A gap between samples means the Mac slept or the app was suspended. The input
        // clock can restart on wake, so the gap itself is the evidence.
        if awaySince == nil, let lastSample, now.timeIntervalSince(lastSample) >= threshold {
            awaySince = lastSample
        }
        if idleSeconds >= threshold {
            awaySince = awaySince ?? now.addingTimeInterval(-idleSeconds)
            return nil
        }
        guard let since = awaySince else { return nil }
        awaySince = nil
        return AwayPeriod(start: since, end: now.addingTimeInterval(-idleSeconds))
    }

    /// Forgets any away state, for when the timer is stopped by hand.
    public mutating func reset() {
        awaySince = nil
    }
}
