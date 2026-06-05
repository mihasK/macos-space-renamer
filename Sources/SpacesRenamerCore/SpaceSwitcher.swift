import CoreGraphics
import Darwin
import Foundation

public final class SpaceSwitcher {
    fileprivate typealias MainConnectionFunction = @convention(c) () -> UInt32
    fileprivate typealias SetCurrentSpaceFunction = @convention(c) (UInt32, CFString, UInt64) -> Void

    private let mainConnection: MainConnectionFunction?
    private let setCurrentSpace: SetCurrentSpaceFunction?

    public init() {
        let symbols = SpaceSwitcherSymbols.shared
        mainConnection = symbols.mainConnection
        setCurrentSpace = symbols.setCurrentSpace
    }

    @discardableResult
    public func switchToSpace(_ space: DesktopSpace) -> Bool {
        if let mainConnection, let setCurrentSpace {
            setCurrentSpace(mainConnection(), space.displayIdentifier as CFString, UInt64(space.managedSpaceID))
            return true
        }

        return switchUsingKeyboardShortcut(desktopNumber: space.desktopIndex + 1)
    }

    private func switchUsingKeyboardShortcut(desktopNumber: Int) -> Bool {
        guard let keyCode = keyCode(forDesktopNumber: desktopNumber) else {
            return false
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

        keyDown?.flags = .maskControl
        keyUp?.flags = .maskControl
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        return keyDown != nil && keyUp != nil
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
        case 10: 29
        default: nil
        }
    }
}

private final class SpaceSwitcherSymbols {
    static let shared = SpaceSwitcherSymbols()

    let mainConnection: SpaceSwitcher.MainConnectionFunction?
    let setCurrentSpace: SpaceSwitcher.SetCurrentSpaceFunction?

    private init() {
        let handle = Self.openCoreGraphics()

        mainConnection = Self.loadSymbol(
            "CGSMainConnectionID",
            from: handle,
            as: SpaceSwitcher.MainConnectionFunction.self
        )
        setCurrentSpace = Self.loadSymbol(
            "CGSManagedDisplaySetCurrentSpace",
            from: handle,
            as: SpaceSwitcher.SetCurrentSpaceFunction.self
        )
    }

    private static func openCoreGraphics() -> UnsafeMutableRawPointer? {
        let paths = [
            "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
            "/System/Library/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"
        ]

        for path in paths {
            if let handle = dlopen(path, RTLD_LAZY | RTLD_LOCAL) {
                return handle
            }
        }

        return nil
    }

    private static func loadSymbol<T>(
        _ name: String,
        from handle: UnsafeMutableRawPointer?,
        as type: T.Type
    ) -> T? {
        let processHandle = UnsafeMutableRawPointer(bitPattern: -2)
        let symbol = handle.flatMap { dlsym($0, name) } ?? dlsym(processHandle, name)

        guard let symbol else {
            return nil
        }

        return unsafeBitCast(symbol, to: type)
    }
}
