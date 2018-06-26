import Foundation

/// Naive implementation of a thread "safe" dictionary.
/// This ~may~ will go horribly wrong.
class ThreadSafeDictionary<K: Hashable, V> {
    private var dict: [K: V] = [:]
    private let lock = NSLock()

    subscript(key: K) -> V? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return dict[key]
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            dict[key] = newValue
        }
    }

    func forEach(_ body: ((key: K, value: V)) throws -> Void) rethrows {
        lock.lock()
        defer { lock.unlock() }
        try dict.forEach(body)
    }

    var keys: Dictionary<K, V>.Keys {
        lock.lock()
        defer { lock.unlock() }
        return dict.keys
    }
}
