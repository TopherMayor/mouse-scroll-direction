import Foundation

public enum ScrollDevice: Equatable {
    case mouse
    case trackpad
    case unknown
}

public struct ScrollDeltas: Equatable {
    public var vertical: Double
    public var horizontal: Double

    public init(vertical: Double, horizontal: Double) {
        self.vertical = vertical
        self.horizontal = horizontal
    }
}

/// Mutable at runtime — the menu toggles `reverseMouse` and `reverseTrackpad`.
/// Settings persist via UserDefaults with keys `msd.reverseMouse` and `msd.reverseTrackpad`.
public final class ScrollPolicy {
    public var reverseMouse: Bool {
        didSet { UserDefaults.standard.set(reverseMouse, forKey: "msd.reverseMouse") }
    }
    public var reverseTrackpad: Bool {
        didSet { UserDefaults.standard.set(reverseTrackpad, forKey: "msd.reverseTrackpad") }
    }

    public init() {
        let defaults = UserDefaults.standard
        self.reverseMouse = defaults.object(forKey: "msd.reverseMouse") as? Bool ?? true
        self.reverseTrackpad = defaults.object(forKey: "msd.reverseTrackpad") as? Bool ?? false
    }

    public func shouldReverse(_ device: ScrollDevice) -> Bool {
        switch device {
        case .mouse: return reverseMouse
        case .trackpad: return reverseTrackpad
        case .unknown: return false
        }
    }
}

/// Classifies the two input types needed by this utility without inspecting device names.
/// Ordinary wheel mice emit non-continuous scroll events; trackpads emit continuous events
/// and normally carry phase, momentum, or scroll-count metadata.
public struct ScrollDeviceClassifier {
    private var lastDevice: ScrollDevice?

    public init() {}

    public mutating func classify(isContinuous: Bool, hasPhase: Bool, hasMomentum: Bool, scrollCount: Double) -> ScrollDevice {
        if !isContinuous {
            lastDevice = .mouse
            return .mouse
        }
        if hasPhase || hasMomentum || scrollCount != 0 {
            lastDevice = .trackpad
            return .trackpad
        }
        let result = lastDevice ?? .unknown
        if result != .unknown { lastDevice = result }
        return result
    }
}
