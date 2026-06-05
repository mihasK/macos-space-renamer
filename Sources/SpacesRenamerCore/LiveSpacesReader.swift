import Darwin
import Foundation

public final class LiveSpacesReader {
    fileprivate typealias MainConnectionFunction = @convention(c) () -> UInt32
    fileprivate typealias CopyManagedDisplaySpacesFunction = @convention(c) (UInt32) -> Unmanaged<CFArray>?

    private let mainConnection: MainConnectionFunction?
    private let copyManagedDisplaySpaces: CopyManagedDisplaySpacesFunction?

    public init() {
        let symbols = LiveCoreGraphicsSymbols.shared
        mainConnection = symbols.mainConnection
        copyManagedDisplaySpaces = symbols.copyManagedDisplaySpaces
    }

    public var isAvailable: Bool {
        mainConnection != nil && copyManagedDisplaySpaces != nil
    }

    public func readDesktopSpaces() -> [DesktopSpace]? {
        guard
            let mainConnection,
            let copyManagedDisplaySpaces,
            let unmanagedDisplays = copyManagedDisplaySpaces(mainConnection()),
            let monitors = unmanagedDisplays.takeRetainedValue() as? [[String: Any]]
        else {
            return nil
        }

        let spaces = SpacesPreferencesReader.parseDesktopSpaces(fromMonitors: monitors)
        return spaces.isEmpty ? nil : spaces
    }
}

private final class LiveCoreGraphicsSymbols {
    static let shared = LiveCoreGraphicsSymbols()

    let mainConnection: LiveSpacesReader.MainConnectionFunction?
    let copyManagedDisplaySpaces: LiveSpacesReader.CopyManagedDisplaySpacesFunction?

    private init() {
        let handle = Self.openCoreGraphics()

        mainConnection = Self.loadSymbol(
            "CGSMainConnectionID",
            from: handle,
            as: LiveSpacesReader.MainConnectionFunction.self
        )
        copyManagedDisplaySpaces = Self.loadSymbol(
            "CGSCopyManagedDisplaySpaces",
            from: handle,
            as: LiveSpacesReader.CopyManagedDisplaySpacesFunction.self
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
