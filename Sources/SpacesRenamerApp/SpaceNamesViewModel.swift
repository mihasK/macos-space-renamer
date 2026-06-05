import Foundation
import SpacesRenamerCore
import SwiftUI

@MainActor
final class SpaceNamesViewModel: ObservableObject {
    @Published private(set) var spaces: [DesktopSpace] = []
    @Published var namesBySpaceID: [Int: String]
    @Published var errorMessage: String?

    private let reader: SpacesPreferencesReader
    private let liveReader = LiveSpacesReader()
    private let store: SpaceNameStore
    private let onChange: () -> Void
    private let onClose: () -> Void

    init(
        reader: SpacesPreferencesReader,
        store: SpaceNameStore,
        onChange: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.reader = reader
        self.store = store
        self.onChange = onChange
        self.onClose = onClose
        self.namesBySpaceID = store.allNames()
        reload()
    }

    func reload() {
        if let liveSpaces = liveReader.readDesktopSpaces() {
            spaces = liveSpaces
            namesBySpaceID = store.allNames()
            errorMessage = nil
        } else {
            do {
                spaces = try reader.readDesktopSpaces()
                namesBySpaceID = store.allNames()
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func binding(for space: DesktopSpace) -> Binding<String> {
        Binding(
            get: { self.namesBySpaceID[space.managedSpaceID] ?? "" },
            set: { newValue in
                self.namesBySpaceID[space.managedSpaceID] = newValue
                self.store.setName(newValue, for: space.managedSpaceID)
                self.onChange()
            }
        )
    }

    func close() {
        onClose()
    }
}
