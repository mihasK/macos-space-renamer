import Carbon
import Foundation

final class GlobalHotKey {
    enum RegistrationError: LocalizedError {
        case registerFailed(OSStatus)
        case installHandlerFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .registerFailed(let status):
                "Could not register global shortcut. OSStatus: \(status)."
            case .installHandlerFailed(let status):
                "Could not install global shortcut handler. OSStatus: \(status)."
            }
        }
    }

    private let handler: @MainActor () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(handler: @escaping @MainActor () -> Void) {
        self.handler = handler
    }

    deinit {
        unregister()
    }

    func registerCommandShiftG() throws {
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
            throw RegistrationError.installHandlerFailed(handlerStatus)
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

        guard registerStatus == noErr else {
            throw RegistrationError.registerFailed(registerStatus)
        }
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
    }

    private static func fourCharCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { result, character in
            (result << 8) + OSType(character)
        }
    }
}
