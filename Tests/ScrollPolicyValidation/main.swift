import MouseScrollDirectionCore

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), "FAIL: \(message)")
    print("PASS: \(message)")
}

let policy = ScrollPolicy(reverseMouse: true, reverseTrackpad: false)
check(policy.transform(ScrollDeltas(vertical: 3, horizontal: -2), for: .mouse) == ScrollDeltas(vertical: -3, horizontal: 2), "mouse deltas reverse")
check(policy.transform(ScrollDeltas(vertical: 3, horizontal: -2), for: .trackpad) == ScrollDeltas(vertical: 3, horizontal: -2), "trackpad deltas stay natural")
check(policy.transform(ScrollDeltas(vertical: 3, horizontal: -2), for: .unknown) == ScrollDeltas(vertical: 3, horizontal: -2), "unknown deltas stay untouched")

var classifier = ScrollDeviceClassifier()
check(classifier.classify(isContinuous: false, hasPhase: false, hasMomentum: false, scrollCount: 0) == .mouse, "ordinary wheel classifies as mouse")
check(classifier.classify(isContinuous: true, hasPhase: true, hasMomentum: false, scrollCount: 0) == .trackpad, "phase metadata classifies as trackpad")
check(classifier.classify(isContinuous: true, hasPhase: false, hasMomentum: true, scrollCount: 0) == .trackpad, "momentum metadata classifies as trackpad")
check(classifier.classify(isContinuous: true, hasPhase: false, hasMomentum: false, scrollCount: 1) == .trackpad, "scroll-count metadata classifies as trackpad")

var freshClassifier = ScrollDeviceClassifier()
check(freshClassifier.classify(isContinuous: true, hasPhase: false, hasMomentum: false, scrollCount: 0) == .unknown, "ambiguous event stays unknown without history")
print("All validation checks passed")
