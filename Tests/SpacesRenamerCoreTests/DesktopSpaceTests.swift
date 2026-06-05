import XCTest
@testable import SpacesRenamerCore

final class DesktopSpaceTests: XCTestCase {
    func testMarkingCurrentReturnsUpdatedCopy() {
        let space = DesktopSpace(
            managedSpaceID: 42,
            uuid: "space-uuid",
            displayIdentifier: "Main",
            displayIndex: 0,
            desktopIndex: 3,
            isCurrent: false
        )

        let updatedSpace = space.markingCurrent(true)

        XCTAssertEqual(updatedSpace.managedSpaceID, 42)
        XCTAssertEqual(updatedSpace.uuid, "space-uuid")
        XCTAssertEqual(updatedSpace.displayIdentifier, "Main")
        XCTAssertEqual(updatedSpace.displayIndex, 0)
        XCTAssertEqual(updatedSpace.desktopIndex, 3)
        XCTAssertTrue(updatedSpace.isCurrent)
    }
}
