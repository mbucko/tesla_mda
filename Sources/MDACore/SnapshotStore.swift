import Foundation

/// Persists the last good snapshot and the last celebrated million.
public final class SnapshotStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let snapshotKey = "counterSnapshot"
    private let lastCelebratedKey = "lastCelebratedMillion"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadSnapshot() -> CounterSnapshot? {
        defaults.data(forKey: snapshotKey).flatMap { try? JSONDecoder().decode(CounterSnapshot.self, from: $0) }
    }

    public func save(_ snapshot: CounterSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: snapshotKey)
        }
    }

    public var lastCelebratedMillion: Int {
        get { defaults.integer(forKey: lastCelebratedKey) }
        set { defaults.set(newValue, forKey: lastCelebratedKey) }
    }
}
