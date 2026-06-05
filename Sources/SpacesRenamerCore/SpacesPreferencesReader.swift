import Foundation

public enum SpacesPreferencesError: LocalizedError {
    case preferencesNotFound(URL)
    case invalidPreferences

    public var errorDescription: String? {
        switch self {
        case .preferencesNotFound(let url):
            "Spaces preferences were not found at \(url.path)."
        case .invalidPreferences:
            "Spaces preferences did not have the expected structure."
        }
    }
}

public final class SpacesPreferencesReader {
    private let preferencesURL: URL

    public init(
        preferencesURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.spaces.plist")
    ) {
        self.preferencesURL = preferencesURL
    }

    public func readDesktopSpaces() throws -> [DesktopSpace] {
        guard FileManager.default.fileExists(atPath: preferencesURL.path) else {
            throw SpacesPreferencesError.preferencesNotFound(preferencesURL)
        }

        let data = try Data(contentsOf: preferencesURL)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)

        guard let root = plist as? [String: Any] else {
            throw SpacesPreferencesError.invalidPreferences
        }

        return try Self.parseDesktopSpaces(from: root)
    }

    public static func parseDesktopSpaces(from root: [String: Any]) throws -> [DesktopSpace] {
        guard
            let configuration = root["SpacesDisplayConfiguration"] as? [String: Any],
            let managementData = configuration["Management Data"] as? [String: Any],
            let monitors = managementData["Monitors"] as? [[String: Any]]
        else {
            throw SpacesPreferencesError.invalidPreferences
        }

        return parseDesktopSpaces(fromMonitors: monitors)
    }

    public static func parseDesktopSpaces(fromMonitors monitors: [[String: Any]]) -> [DesktopSpace] {
        monitors.enumerated().flatMap { displayIndex, monitor in
            parseMonitor(monitor, displayIndex: displayIndex)
        }
    }

    private static func parseMonitor(_ monitor: [String: Any], displayIndex: Int) -> [DesktopSpace] {
        guard let spaces = monitor["Spaces"] as? [[String: Any]] else {
            return []
        }

        let displayIdentifier = monitor["Display Identifier"] as? String ?? "Display \(displayIndex + 1)"
        let currentSpaceID = spaceID(from: monitor["Current Space"])

        return spaces.enumerated().compactMap { desktopIndex, space in
            let type = intValue(space["type"]) ?? 0

            guard type == 0, let managedSpaceID = spaceID(from: space) else {
                return nil
            }

            let uuid = (space["uuid"] as? String).flatMap { $0.isEmpty ? nil : $0 }

            return DesktopSpace(
                managedSpaceID: managedSpaceID,
                uuid: uuid,
                displayIdentifier: displayIdentifier,
                displayIndex: displayIndex,
                desktopIndex: desktopIndex,
                isCurrent: currentSpaceID == managedSpaceID
            )
        }
    }

    private static func spaceID(from value: Any?) -> Int? {
        guard let space = value as? [String: Any] else {
            return nil
        }

        return intValue(space["ManagedSpaceID"]) ?? intValue(space["id64"]) ?? intValue(space["wsid"])
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber:
            number.intValue
        case let int as Int:
            int
        case let string as String:
            Int(string)
        default:
            nil
        }
    }
}
