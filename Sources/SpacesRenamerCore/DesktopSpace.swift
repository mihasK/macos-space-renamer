import Foundation

public struct DesktopSpace: Identifiable, Equatable {
    public let managedSpaceID: Int
    public let uuid: String?
    public let displayIdentifier: String
    public let displayIndex: Int
    public let desktopIndex: Int
    public let isCurrent: Bool

    public var id: Int { managedSpaceID }

    public var defaultTitle: String {
        "Desktop \(desktopIndex + 1)"
    }

    public init(
        managedSpaceID: Int,
        uuid: String?,
        displayIdentifier: String,
        displayIndex: Int,
        desktopIndex: Int,
        isCurrent: Bool
    ) {
        self.managedSpaceID = managedSpaceID
        self.uuid = uuid
        self.displayIdentifier = displayIdentifier
        self.displayIndex = displayIndex
        self.desktopIndex = desktopIndex
        self.isCurrent = isCurrent
    }

    public func markingCurrent(_ isCurrent: Bool) -> DesktopSpace {
        DesktopSpace(
            managedSpaceID: managedSpaceID,
            uuid: uuid,
            displayIdentifier: displayIdentifier,
            displayIndex: displayIndex,
            desktopIndex: desktopIndex,
            isCurrent: isCurrent
        )
    }
}
