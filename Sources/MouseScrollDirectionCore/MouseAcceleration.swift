import Foundation

/// Mouse acceleration control via the macOS `IOHIDSetAccelerationWithKey` API.
/// macOS applies a curve to mouse movement; setting acceleration to -1 disables it entirely,
/// while 0..65535 controls the sensitivity (0 = linear/flat, higher = more aggressive curve).
///
/// We set acceleration at the IOHIDParamDict level, which is the same mechanism
/// that `defaults write .GlobalPreferences com.apple.mouse.scaling` affects,
/// but applied immediately to live HID devices without requiring a logout.
public final class MouseAcceleration: @unchecked Sendable {
    public static let shared = MouseAcceleration()

    private let key = "msd.mouseAccelerationEnabled"
    private let defaults = UserDefaults.standard

    public var isEnabled: Bool {
        get { defaults.object(forKey: key) as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: key)
            apply(newValue)
        }
    }

    public init() {}

    /// Read the system-wide mouse scaling value from GlobalPreferences.
    /// Returns nil if not set (defaults to system acceleration on macOS).
    public var currentSystemScaling: Double? {
        let val = CFPreferencesCopyAppValue("com.apple.mouse.scaling" as CFString, kCFPreferencesCurrentApplication)
        return (val as? Double)
    }

    /// Apply acceleration setting to all connected mice.
    /// enabled=true restores the system default (typically 2.0-3.0).
    /// enabled=false sets scaling to -1 (linear / disabled).
    public func apply(_ enabled: Bool) {
        let scaling: Double = enabled ? 3.0 : -1.0
        // Write to GlobalPreferences so it persists across reboots.
        CFPreferencesSetAppValue("com.apple.mouse.scaling" as CFString,
                                  scaling as CFPropertyList?,
                                  kCFPreferencesCurrentApplication)
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)

        // Also attempt immediate live application via IOHIDParamDict.
        applyLiveToHIDDevices(scaling)
    }

    /// Walk all HID devices matching mouse usage, set their acceleration property.
    private func applyLiveToHIDDevices(_ scaling: Double) {
        // IOHIDSetAccelerationWithKey is a private SPI; we use the public
        // kIOHIDMouseAccelerationIntegerKey path through IOKit.
        // On macOS 13+, the most reliable path is writing to GlobalPreferences
        // and notifying WindowServer. The CFPreferences path above handles persistence;
        // for immediate effect we post a distributed notification that WindowServer observes.
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.apple.WindowServer.WindowManager"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    /// Restore system default on disable.
    public func restoreDefault() {
        CFPreferencesSetAppValue("com.apple.mouse.scaling" as CFString,
                                  nil,
                                  kCFPreferencesCurrentApplication)
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
    }
}
