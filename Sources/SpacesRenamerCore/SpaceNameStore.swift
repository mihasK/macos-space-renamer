import Foundation

public final class SpaceNameStore {
    private let userDefaults: UserDefaults
    private let key = "spaceNamesByManagedSpaceID"

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func allNames() -> [Int: String] {
        rawNames().reduce(into: [Int: String]()) { result, pair in
            guard let id = Int(pair.key) else {
                return
            }

            result[id] = pair.value
        }
    }

    public func name(for managedSpaceID: Int) -> String? {
        allNames()[managedSpaceID]
    }

    public func setName(_ name: String?, for managedSpaceID: Int) {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var names = rawNames()

        if trimmedName.isEmpty {
            names.removeValue(forKey: String(managedSpaceID))
        } else {
            names[String(managedSpaceID)] = trimmedName
        }

        userDefaults.set(names, forKey: key)
    }

    private func rawNames() -> [String: String] {
        userDefaults.dictionary(forKey: key) as? [String: String] ?? [:]
    }
}
