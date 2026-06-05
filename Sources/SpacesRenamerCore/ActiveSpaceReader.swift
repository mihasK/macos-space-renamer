import Darwin
import Foundation

public final class ActiveSpaceReader {
    fileprivate typealias DefaultConnectionFunction = @convention(c) () -> Int32
    fileprivate typealias GetActiveSpaceFunction = @convention(c) (Int32) -> UInt64

    private let defaultConnection: DefaultConnectionFunction?
    private let getActiveSpace: GetActiveSpaceFunction?

    public init() {
        let symbols = PrivateCoreGraphicsSymbols.shared
        defaultConnection = symbols.defaultConnection
        getActiveSpace = symbols.getActiveSpace
    }

    public func activeSpaceID() -> Int? {
        guard let defaultConnection, let getActiveSpace else {
            return nil
        }

        let connection = defaultConnection()
        let activeSpaceID = getActiveSpace(connection)

        guard activeSpaceID > 0, activeSpaceID <= UInt64(Int.max) else {
            return nil
        }

        return Int(activeSpaceID)
    }
}

private final class PrivateCoreGraphicsSymbols {
    static let shared = PrivateCoreGraphicsSymbols()

    let defaultConnection: ActiveSpaceReader.DefaultConnectionFunction?
    let getActiveSpace: ActiveSpaceReader.GetActiveSpaceFunction?

    private init() {
        let handle = Self.openCoreGraphics()

        defaultConnection = Self.loadSymbol(
            "_CGSDefaultConnection",
            from: handle,
            as: ActiveSpaceReader.DefaultConnectionFunction.self
        )
        getActiveSpace = Self.loadSymbol(
            "CGSGetActiveSpace",
            from: handle,
            as: ActiveSpaceReader.GetActiveSpaceFunction.self
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
