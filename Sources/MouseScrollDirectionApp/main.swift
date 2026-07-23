import AppKit
import CoreGraphics
import MouseScrollDirectionCore

final class ScrollEventTap {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var classifier = ScrollDeviceClassifier()
    let policy = ScrollPolicy()

    @MainActor func start() -> Bool {
        if tap != nil && source != nil { return true }
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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "arrow.up.arrow.down", accessibilityDescription: "Mouse Scroll Direction")
            button.image?.isTemplate = true
        }
        rebuildMenu()
        tryStartTap()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        // Scroll direction section
        let reverseItem = NSMenuItem(title: "Reverse Mouse Scrolling", action: #selector(toggleReverseMouse), keyEquivalent: "")
        reverseItem.target = self
        reverseItem.state = eventTap.policy.reverseMouse ? .on : .off
        reverseItem.toolTip = "When enabled, mouse scroll direction is inverse of trackpad"
        menu.addItem(reverseItem)

        menu.addItem(.separator())

        // Mouse acceleration section
        let accelHeader = NSMenuItem(title: "Mouse Acceleration", action: nil, keyEquivalent: "")
        accelHeader.isEnabled = false
        menu.addItem(accelHeader)

        let accelItem = NSMenuItem(title: "Enabled", action: #selector(toggleAcceleration), keyEquivalent: "")
        accelItem.target = self
        accelItem.state = MouseAcceleration.shared.isEnabled ? .on : .off
        accelItem.indentationLevel = 1
        menu.addItem(accelItem)

        let statusText = MouseAcceleration.shared.currentSystemScaling.map { String(format: "Current scaling: %.1f", $0) } ?? "Current scaling: system default"
        let scalingItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        scalingItem.isEnabled = false
        scalingItem.indentationLevel = 1
        menu.addItem(scalingItem)

        menu.addItem(.separator())

        // About / Quit
        let aboutItem = NSMenuItem(title: "About Mouse Scroll Direction", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func toggleReverseMouse() {
        eventTap.policy.reverseMouse.toggle()
        rebuildMenu()
    }

    @objc private func toggleAcceleration() {
        MouseAcceleration.shared.isEnabled.toggle()
        rebuildMenu()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Mouse Scroll Direction"
        alert.informativeText = """
            Reverses mouse scroll direction relative to trackpad.

            Mouse scrolling: \(eventTap.policy.reverseMouse ? "Reversed (inverse of trackpad)" : "Same as trackpad")
            Mouse acceleration: \(MouseAcceleration.shared.isEnabled ? "Enabled" : "Disabled")

            Settings are saved automatically.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        if let window = NSApp.windows.first(where: { $0.isVisible }) {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }

    @MainActor private func tryStartTap() {
        if eventTap.start() {
            return
        }
        NSLog("Unable to create scroll event tap. Grant Accessibility permission to MouseScrollDirection. Will retry in 5 seconds.")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.tryStartTap()
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
