import ApplicationServices
import AppKit
import Carbon

final class GlobalHotKey {
    enum RegistrationStatus: Equatable {
        case doubleControl
        case doubleControlNeedsAccessibility
        case commandShiftGFallback
        case unavailable

        var displayText: String {
            switch self {
            case .doubleControl:
                "Opener: double Control"
            case .doubleControlNeedsAccessibility:
                "Double Control needs Accessibility"
            case .commandShiftGFallback:
                "Opener: ⇧⌘G"
            case .unavailable:
                "Opener unavailable"
            }
        }
    }

    private let maximumTapDuration: TimeInterval = 0.35
    private let maximumControlTapInterval: TimeInterval = 0.45
    private let handler: @MainActor () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var doubleControlGlobalMonitor: Any?
    private var doubleControlLocalMonitor: Any?
    private var controlDownDate: Date?
    private var controlIsDown = false
    private var currentTapInvalid = false
    private var lastControlTapDate: Date?
    private var consecutiveControlTapCount = 0

    init(handler: @escaping @MainActor () -> Void) {
        self.handler = handler
    }

    deinit {
        unregister()
    }

    func registerOpeners(promptForAccessibility: Bool) -> RegistrationStatus {
        let fallbackAvailable = registerCommandShiftGFallbackIfNeeded()
        let doubleControlReady = refreshDoubleControlMonitor(promptForAccessibility: promptForAccessibility)

        if doubleControlReady {
            return .doubleControl
        }

        if !isAccessibilityTrusted(prompt: false) {
            return fallbackAvailable ? .doubleControlNeedsAccessibility : .unavailable
        }

        return fallbackAvailable ? .commandShiftGFallback : .unavailable
    }

    var isDoubleControlReady: Bool {
        (doubleControlGlobalMonitor != nil || doubleControlLocalMonitor != nil)
            && isAccessibilityTrusted(prompt: false)
    }

    private func registerCommandShiftGFallbackIfNeeded() -> Bool {
        if hotKeyRef != nil {
            return true
        }

        if eventHandlerRef == nil {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: OSType(kEventHotKeyPressed)
            )

            let handlerStatus = InstallEventHandler(
                GetApplicationEventTarget(),
                { _, _, userData in
                    guard let userData else {
                        return noErr
                    }

                    let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                    Task { @MainActor in
                        hotKey.handler()
                    }
                    return noErr
                },
                1,
                &eventType,
                Unmanaged.passUnretained(self).toOpaque(),
                &eventHandlerRef
            )

            guard handlerStatus == noErr else {
                return false
            }
        }

        let hotKeyID = EventHotKeyID(signature: Self.fourCharCode("SPRN"), id: 1)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_G),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        return registerStatus == noErr
    }

    private func refreshDoubleControlMonitor(promptForAccessibility: Bool) -> Bool {
        guard isAccessibilityTrusted(prompt: promptForAccessibility) else {
            return false
        }

        if doubleControlGlobalMonitor == nil {
            let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]
            doubleControlGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
                self?.handle(event)
            }
        }

        if doubleControlLocalMonitor == nil {
            let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]
            doubleControlLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
                self?.handle(event)
                return event
            }
        }

        return doubleControlGlobalMonitor != nil || doubleControlLocalMonitor != nil
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }

        if let doubleControlGlobalMonitor {
            NSEvent.removeMonitor(doubleControlGlobalMonitor)
            self.doubleControlGlobalMonitor = nil
        }

        if let doubleControlLocalMonitor {
            NSEvent.removeMonitor(doubleControlLocalMonitor)
            self.doubleControlLocalMonitor = nil
        }
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            handleFlagsChanged(event)
        case .keyDown:
            handleKeyDown()
        default:
            break
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let now = Date()
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let controlDown = flags.contains(.control)
        let otherModifierDown = flags.intersection([.command, .option, .shift, .function]).isEmpty == false

        if controlDown, !controlIsDown {
            controlIsDown = true
            controlDownDate = now
            currentTapInvalid = otherModifierDown
        } else if !controlDown, controlIsDown {
            let tapDuration = controlDownDate.map { now.timeIntervalSince($0) } ?? .infinity
            let cleanTap = !currentTapInvalid && !otherModifierDown && tapDuration <= maximumTapDuration

            controlIsDown = false
            controlDownDate = nil
            currentTapInvalid = false

            if cleanTap {
                recordControlTap(at: now)
            } else {
                resetControlTapSequence()
            }
        } else if controlDown, otherModifierDown {
            currentTapInvalid = true
        } else if otherModifierDown {
            resetControlTapSequence()
        }
    }

    private func handleKeyDown() {
        if controlIsDown {
            currentTapInvalid = true
        } else {
            resetControlTapSequence()
        }
    }

    private func recordControlTap(at date: Date) {
        if
            let lastControlTapDate,
            date.timeIntervalSince(lastControlTapDate) <= maximumControlTapInterval
        {
            consecutiveControlTapCount += 1
        } else {
            consecutiveControlTapCount = 1
        }

        lastControlTapDate = date

        if consecutiveControlTapCount == 2 || consecutiveControlTapCount == 3 {
            Task { @MainActor in
                handler()
            }
        }

        if consecutiveControlTapCount >= 3 {
            resetControlTapSequence()
        }
    }

    private func resetControlTapSequence() {
        lastControlTapDate = nil
        consecutiveControlTapCount = 0
    }

    private func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(options)
    }

    private static func fourCharCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { result, character in
            (result << 8) + OSType(character)
        }
    }
}
