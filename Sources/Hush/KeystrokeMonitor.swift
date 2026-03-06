import CoreGraphics
import Foundation

/// Monitors global keystrokes via CGEventTap and detects typing pauses.
final class KeystrokeMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pauseWorkItem: DispatchWorkItem?
    private(set) var pauseDelay: TimeInterval
    private let onPauseDetected: () -> Void
    private(set) var isRunning = false
    var isPaused = false

    init(pauseDelay: TimeInterval = 2.0, onPauseDetected: @escaping () -> Void) {
        self.pauseDelay = pauseDelay
        self.onPauseDetected = onPauseDetected
    }

    func updatePauseDelay(_ delay: TimeInterval) {
        pauseDelay = delay
        Log.info("Pause delay updated to \(delay)s")
    }

    func start() -> Bool {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo in
                guard let monitor = userInfo.map({ Unmanaged<KeystrokeMonitor>.fromOpaque($0).takeUnretainedValue() }) else {
                    return Unmanaged.passUnretained(event)
                }
                monitor.handleKeyEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Log.error("Failed to create CGEventTap")
            Log.error("Grant Accessibility permission: System Settings → Privacy & Security → Accessibility")
            return false
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true

        Log.info("Keystroke monitor started (pause delay: \(pauseDelay)s)")
        return true
    }

    func stop() {
        pauseWorkItem?.cancel()
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isRunning = false
        Log.info("Keystroke monitor stopped")
    }

    private func handleKeyEvent(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByUserInput || type == .tapDisabledByTimeout {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                Log.warn("Event tap was disabled by system — re-enabled")
            }
            return
        }

        if isPaused { return }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Ignore modifier-only keys
        let ignoredKeyCodes: Set<Int64> = [
            54, 55, 56, 57, 58, 59, 60, 61, 62, 63,
        ]
        if ignoredKeyCodes.contains(keyCode) { return }

        resetPauseTimer()
    }

    private func resetPauseTimer() {
        pauseWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.isPaused else { return }
            self.onPauseDetected()
        }
        pauseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + pauseDelay, execute: workItem)
    }
}
