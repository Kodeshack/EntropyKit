
class CacheHierarchy<V>: Cache<V> {
    let caches: [Cache<V>]
    private let propagate: Bool

    /// Initialise a new cache hierarchy.
    ///
    /// - Parameter caches: Caches will be hit in order, starting with the first cache in the argument list.
    convenience init(_ caches: Cache<V>...) {
        self.init(propagate: false, caches: caches)
    }

    /// Initialise a new cache hierarchy.
    ///
    /// - Parameter propagate: Propagate set, remove and clear operations to all caches.
    /// - Parameter caches: Caches will be hit in order, starting with the first cache in the argument list.
    convenience init(propagate: Bool, caches: Cache<V>...) {
        self.init(propagate: propagate, caches: caches)
    }

    /// Initialise a new cache hierarchy.
    ///
    /// - Parameter propagate: Propagate set, remove and clear operations to all caches.
    /// - Parameter caches: Caches will be hit in order, starting with the first cache in the argument list.
    private init(propagate: Bool, caches: [Cache<V>]) {
        self.propagate = propagate
        self.caches = caches
    }

    override func get(_ key: String, meta: Any? = nil) -> V? {
        for i in 0 ..< caches.count {
            if let value = caches[i][key, meta] {
                // if value is found in a cache further down the chain, propagate the value up
                // to the other caches that come before it in the hierachy.
                for j in 0 ..< i { // possible future optimisation: make async
                    caches[j].set(key, object: value)
                }

                return value
            }
        }
        return nil
    }

    override func set(_ key: String, object: V?, cost: Int = 0) {
        caches.first!.set(key, object: object, cost: cost)

        guard propagate else {
            return
        }

        for i in 1 ..< caches.count {
            // possible future optimisation: make async
            caches[i].set(key, object: object, cost: cost)
        }
    }

    override func clear() {
        caches.first!.clear()

        guard propagate else {
            return
        }

        for i in 1 ..< caches.count {
            // possible future optimisation: make async
            caches[i].clear()
        }
    }

    override func remove(_ key: String) {
        caches.first!.remove(key)

        guard propagate else {
            return
        }

        for i in 1 ..< caches.count {
            // possible future optimisation: make async
            caches[i].remove(key)
        }
    }
}
