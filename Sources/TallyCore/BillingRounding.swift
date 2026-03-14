import Foundation

/// How tracked time turns into billable time. Many freelancers bill in 6 or 15 minute
/// increments; the default of 0 bills the exact time.
public struct BillingRounding: Hashable, Codable, Sendable {
    public enum Mode: String, Hashable, Codable, Sendable, CaseIterable {
        case nearest
        case up
    }

    public var incrementMinutes: Int
    public var mode: Mode

    public init(incrementMinutes: Int = 0, mode: Mode = .nearest) {
        self.incrementMinutes = incrementMinutes
        self.mode = mode
    }

    public func billable(seconds: Int) -> Int {
        let step = incrementMinutes*60
        guard step > 0, seconds > 0 else { return max(0, seconds) }
        switch mode {
        case .up:
            return (seconds + step - 1) / step * step
        case .nearest:
            return (seconds + step / 2) / step * step
        }
    }
}
