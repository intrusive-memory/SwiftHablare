@preconcurrency import Foundation

// UserDefaults is inherently thread-safe, so we can safely conform it to Sendable for testing
extension UserDefaults: @unchecked @retroactive Sendable {}

/// Creates a `UserDefaults` instance suitable for tests on all platforms and a
/// cleanup closure that clears any persisted values written during the test.
///
/// - Parameter suiteName: Preferred suite name to isolate defaults when the
///   platform supports custom suites.
/// - Returns: Tuple containing the defaults instance and a cleanup closure.
func makeTestUserDefaults(suiteName: String) -> (defaults: UserDefaults, cleanup: () -> Void) {
    if let defaults = UserDefaults(suiteName: suiteName) {
        defaults.removePersistentDomain(forName: suiteName)
        let cleanup = {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return (defaults, cleanup)
    }

    let defaults = UserDefaults.standard
    let cleanup = {
        let keys = defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("voiceProvider.") }
        for key in keys {
            defaults.removeObject(forKey: key)
        }
    }
    cleanup()
    return (defaults, cleanup)
}
