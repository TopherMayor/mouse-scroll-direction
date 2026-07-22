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

public struct ScrollPolicy {
    public var reverseMouse: Bool
    public var reverseTrackpad: Bool

    public init(reverseMouse: Bool = true, reverseTrackpad: Bool = false) {
        self.reverseMouse = reverseMouse
        self.reverseTrackpad = reverseTrackpad
    }

    public func shouldReverse(_ device: ScrollDevice) -> Bool {
        switch device {
        case .mouse: return reverseMouse
        case .trackpad: return reverseTrackpad
        case .unknown: return false
        }
    }

    public func transform(_ deltas: ScrollDeltas, for device: ScrollDevice) -> ScrollDeltas {
        guard shouldReverse(device) else { return deltas }
        return ScrollDeltas(vertical: -deltas.vertical, horizontal: -deltas.horizontal)
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
        // Ambiguous continuous events inherit the most recent known source. If there
        // is no history, leave them untouched rather than risking a trackpad reversal.
        let result = lastDevice ?? .unknown
        if result != .unknown { lastDevice = result }
        return result
    }
}
