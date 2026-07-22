import AppKit
import CoreGraphics
import MouseScrollDirectionCore

final class ScrollEventTap {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var classifier = ScrollDeviceClassifier()
    private let policy = ScrollPolicy(reverseMouse: true, reverseTrackpad: false)

    func start() -> Bool {
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let owner = Unmanaged<ScrollEventTap>.fromOpaque(userInfo).takeUnretainedValue()
                if type == .tapDisabledByTimeout {
                    owner.reenable()
                    return Unmanaged.passUnretained(event)
                }
                return owner.process(type: type, event: event)
            },
            userInfo: userInfo
        )
        guard let tap else { return false }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func process(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .scrollWheel else { return Unmanaged.passUnretained(event) }
        let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        let hasPhase = event.getDoubleValueField(.scrollWheelEventScrollPhase) != 0
        let hasMomentum = event.getDoubleValueField(.scrollWheelEventMomentumPhase) != 0
        let scrollCount = event.getDoubleValueField(.scrollWheelEventScrollCount)
        let device = classifier.classify(isContinuous: continuous, hasPhase: hasPhase, hasMomentum: hasMomentum, scrollCount: scrollCount)
        guard policy.shouldReverse(device) else { return Unmanaged.passUnretained(event) }
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1))
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2))
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1))
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: -event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2))
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
        return Unmanaged.passUnretained(event)
    }

    private func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let eventTap = ScrollEventTap()
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⇅"
        let menu = NSMenu()
        menu.addItem(withTitle: "Mouse scrolling reversed", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        guard eventTap.start() else {
            NSLog("Unable to create scroll event tap. Grant Accessibility permission to MouseScrollDirection.")
            NSApp.terminate(nil)
            return
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
