import CoreGraphics
import ApplicationServices
import Foundation

public enum SpaceSwitchResult: Equatable {
    case alreadyCurrent
    case started
    case needsAccessibilityPermission
    case unavailable
}

public final class SpaceSwitcher {
    public init() {}

    @discardableResult
    public func switchToSpace(_ targetSpace: DesktopSpace, from currentSpace: DesktopSpace?) -> SpaceSwitchResult {
        if currentSpace?.managedSpaceID == targetSpace.managedSpaceID {
            return .alreadyCurrent
        }

        guard isAccessibilityTrusted(prompt: true) else {
            return .needsAccessibilityPermission
        }

        if targetSpace.desktopIndex < 9 {
            switchUsingDesktopNumberShortcut(desktopNumber: targetSpace.desktopIndex + 1)
            return .started
        }

        if
            let currentSpace,
            currentSpace.displayIndex == targetSpace.displayIndex,
            currentSpace.desktopIndex != targetSpace.desktopIndex
        {
            switchUsingRelativeKeyboardShortcuts(
                delta: targetSpace.desktopIndex - currentSpace.desktopIndex
            )
            return .started
        }

        return .unavailable
    }

    private func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(options)
    }

    private func switchUsingRelativeKeyboardShortcuts(delta: Int) {
        let keyCode: CGKeyCode = delta > 0 ? 124 : 123
        let steps = abs(delta)
        let flags: CGEventFlags = [.maskControl, .maskSecondaryFn]

        DispatchQueue.global(qos: .userInitiated).async {
            for step in 0..<steps {
                self.postKey(keyCode, flags: flags)

                if step < steps - 1 {
                    Thread.sleep(forTimeInterval: 0.28)
                }
            }
        }
    }

    private func switchUsingDesktopNumberShortcut(desktopNumber: Int) {
        guard let keyCode = keyCode(forDesktopNumber: desktopNumber) else {
            return
        }
        postKey(keyCode, flags: .maskControl)
    }

    private func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

        keyDown?.flags = flags
        keyUp?.flags = flags
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func keyCode(forDesktopNumber desktopNumber: Int) -> CGKeyCode? {
        switch desktopNumber {
        case 1: 18
        case 2: 19
        case 3: 20
        case 4: 21
        case 5: 23
        case 6: 22
        case 7: 26
        case 8: 28
        case 9: 25
        default: nil
        }
    }
}
