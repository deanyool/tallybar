import Foundation
import Testing
@testable import TallyCore

@Suite("Idle detection")
struct IdleMonitorTests {
    private let t0 = Fixtures.at("2025-10-15T09:00:00-04:00")

    private func time(_ offset: TimeInterval) -> Date {
        t0.addingTimeInterval(offset)
    }

    @Test func activeUserIsNeverAway() {
        var monitor = IdleMonitor(threshold: 300)
        for tick in 0..<20 {
            #expect(monitor.sample(now: time(Double(tick) * 15), idleSeconds: 3, isTracking: true) == nil)
        }
        #expect(!monitor.isAway)
    }

    @Test func reportsTheFullStretchOnReturn() {
        var monitor = IdleMonitor(threshold: 300)
        #expect(monitor.sample(now: time(0), idleSeconds: 0, isTracking: true) == nil)
        for tick in stride(from: 15.0, through: 285, by: 15) {
            #expect(monitor.sample(now: time(tick), idleSeconds: tick - 1, isTracking: true) == nil)
        }
        #expect(!monitor.isAway)
        #expect(monitor.sample(now: time(301), idleSeconds: 300, isTracking: true) == nil)
        #expect(monitor.isAway)
        #expect(monitor.sample(now: time(315), idleSeconds: 314, isTracking: true) == nil)
        let away = monitor.sample(now: time(330), idleSeconds: 2, isTracking: true)
        #expect(away == AwayPeriod(start: time(1), end: time(328)))
        #expect(!monitor.isAway)
    }

    @Test func oneReturnGivesOnePrompt() {
        var monitor = IdleMonitor(threshold: 60)
        _ = monitor.sample(now: time(0), idleSeconds: 0, isTracking: true)
        _ = monitor.sample(now: time(50), idleSeconds: 60, isTracking: true)
        #expect(monitor.sample(now: time(65), idleSeconds: 0, isTracking: true) != nil)
        #expect(monitor.sample(now: time(70), idleSeconds: 0, isTracking: true) == nil)
    }

    @Test func notTrackingIsIgnored() {
        var monitor = IdleMonitor(threshold: 60)
        #expect(monitor.sample(now: time(0), idleSeconds: 5000, isTracking: false) == nil)
        #expect(!monitor.isAway)
    }

    @Test func zeroThresholdDisablesDetection() {
        var monitor = IdleMonitor(threshold: 0)
        #expect(monitor.sample(now: time(0), idleSeconds: 5000, isTracking: true) == nil)
        #expect(!monitor.isAway)
    }

    @Test func stoppingWhileAwayForgetsIt() {
        var monitor = IdleMonitor(threshold: 60)
        _ = monitor.sample(now: time(0), idleSeconds: 120, isTracking: true)
        #expect(monitor.isAway)
        #expect(monitor.sample(now: time(15), idleSeconds: 135, isTracking: false) == nil)
        #expect(!monitor.isAway)
    }

    @Test func sleepShowsUpAsAGapBetweenSamples() {
        // The Mac slept for an hour. The input clock restarted on wake.
        var monitor = IdleMonitor(threshold: 300)
        _ = monitor.sample(now: time(0), idleSeconds: 1, isTracking: true)
        let away = monitor.sample(now: time(3600), idleSeconds: 1, isTracking: true)
        #expect(away == AwayPeriod(start: time(0), end: time(3599)))
    }

    @Test func wakingWithoutTouchingAnythingWaitsForInput() {
        var monitor = IdleMonitor(threshold: 300)
        _ = monitor.sample(now: time(0), idleSeconds: 1, isTracking: true)
        #expect(monitor.sample(now: time(3600), idleSeconds: 3000, isTracking: true) == nil)
        #expect(monitor.isAway)
        let away = monitor.sample(now: time(3700), idleSeconds: 1, isTracking: true)
        #expect(away?.start == time(0))
    }

    @Test func aTimerHiccupBelowTheThresholdIsNotAway() {
        var monitor = IdleMonitor(threshold: 300)
        _ = monitor.sample(now: time(0), idleSeconds: 1, isTracking: true)
        #expect(monitor.sample(now: time(200), idleSeconds: 1, isTracking: true) == nil)
    }

    @Test func resetClearsAwayState() {
        var monitor = IdleMonitor(threshold: 60)
        _ = monitor.sample(now: time(0), idleSeconds: 120, isTracking: true)
        monitor.reset()
        #expect(!monitor.isAway)
    }
}
