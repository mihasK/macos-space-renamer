import XCTest
@testable import SpacesRenamerCore

final class SpacesPreferencesReaderTests: XCTestCase {
    func testParseDesktopSpacesReadsCurrentSpace() throws {
        let root: [String: Any] = [
            "SpacesDisplayConfiguration": [
                "Management Data": [
                    "Monitors": [
                        [
                            "Display Identifier": "Main",
                            "Current Space": [
                                "ManagedSpaceID": 7,
                                "type": 0
                            ],
                            "Spaces": [
                                [
                                    "ManagedSpaceID": 5,
                                    "type": 0,
                                    "uuid": "first"
                                ],
                                [
                                    "ManagedSpaceID": 7,
                                    "type": 0,
                                    "uuid": "second"
                                ],
                                [
                                    "ManagedSpaceID": 9,
                                    "type": 4,
                                    "uuid": "fullscreen"
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let spaces = try SpacesPreferencesReader.parseDesktopSpaces(from: root)

        XCTAssertEqual(spaces.map(\.managedSpaceID), [5, 7])
        XCTAssertEqual(spaces.map(\.defaultTitle), ["Desktop 1", "Desktop 2"])
        XCTAssertFalse(spaces[0].isCurrent)
        XCTAssertTrue(spaces[1].isCurrent)
    }

    func testParseDesktopSpacesSupportsNSNumberIDs() throws {
        let root: [String: Any] = [
            "SpacesDisplayConfiguration": [
                "Management Data": [
                    "Monitors": [
                        [
                            "Display Identifier": "Main",
                            "Current Space": [
                                "id64": NSNumber(value: 42)
                            ],
                            "Spaces": [
                                [
                                    "id64": NSNumber(value: 42),
                                    "type": NSNumber(value: 0),
                                    "uuid": ""
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let spaces = try SpacesPreferencesReader.parseDesktopSpaces(from: root)

        XCTAssertEqual(spaces.count, 1)
        XCTAssertEqual(spaces[0].managedSpaceID, 42)
        XCTAssertNil(spaces[0].uuid)
        XCTAssertTrue(spaces[0].isCurrent)
    }
}
