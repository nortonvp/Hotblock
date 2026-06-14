import Foundation

final class PersistenceStore {
    private enum Key {
        static let state = "hotblock.persistedState.v2"
        static let legacyWebsites = "hotblock.websites"
        static let legacyIsBlocking = "hotblock.isBlocking"
        static let legacyUnlockWordCount = "hotblock.unlockWordCount"
        static let legacyUnlockWords = "hotblock.unlockWords"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> PersistedState {
        if let data = defaults.data(forKey: Key.state),
           let state = try? decoder.decode(PersistedState.self, from: data) {
            return state
        }

        let hasLegacyState =
            defaults.object(forKey: Key.legacyWebsites) != nil ||
            defaults.object(forKey: Key.legacyIsBlocking) != nil

        var state = PersistedState()
        state.websites = defaults.stringArray(forKey: Key.legacyWebsites) ?? []
        state.isBlocking = defaults.bool(forKey: Key.legacyIsBlocking)
        state.unlockWordCount = min(max(defaults.integer(forKey: Key.legacyUnlockWordCount), 1), 300)
        state.unlockWords = defaults.stringArray(forKey: Key.legacyUnlockWords) ?? []
        state.setupCompleted = hasLegacyState
        return state
    }

    func save(_ state: PersistedState) {
        if let data = try? encoder.encode(state) {
            defaults.set(data, forKey: Key.state)
        }

        // The temporary watchdog reads this mirrored value without decoding JSON.
        defaults.set(state.isBlocking, forKey: Key.legacyIsBlocking)
    }
}
