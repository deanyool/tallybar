import Foundation
import ServiceManagement

/// Starting at login, as closures so a view can be rendered without touching the system.
public struct LaunchAtLoginControl: Sendable {
    public var isAvailable: Bool
    public var isEnabled: @Sendable () -> Bool
    public var setEnabled: @Sendable (Bool) throws -> Void

    public init(
        isAvailable: Bool,
        isEnabled: @escaping @Sendable () -> Bool,
        setEnabled: @escaping @Sendable (Bool) throws -> Void
    ) {
        self.isAvailable = isAvailable
        self.isEnabled = isEnabled
        self.setEnabled = setEnabled
    }

    /// The real thing, via `SMAppService`. It only works from an app bundle, so
    /// `swift run` shows the setting as unavailable rather than failing.
    public static var system: LaunchAtLoginControl {
        LaunchAtLoginControl(
            isAvailable: Bundle.main.bundleURL.pathExtension == "app",
            isEnabled: { SMAppService.mainApp.status == .enabled },
            setEnabled: { enabled in
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            }
        )
    }
}
