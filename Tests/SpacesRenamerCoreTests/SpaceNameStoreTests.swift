import XCTest
@testable import SpacesRenamerCore

final class SpaceNameStoreTests: XCTestCase {
    func testSetNameStoresTrimmedName() {
        let userDefaults = makeUserDefaults()
        let store = SpaceNameStore(userDefaults: userDefaults)

        store.setName("  Code  ", for: 12)

        XCTAssertEqual(store.name(for: 12), "Code")
    }

    func testEmptyNameRemovesStoredName() {
        let userDefaults = makeUserDefaults()
        let store = SpaceNameStore(userDefaults: userDefaults)

        store.setName("Writing", for: 7)
        store.setName("   ", for: 7)

        XCTAssertNil(store.name(for: 7))
    }

    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "SpacesRenamerTests-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }
}
