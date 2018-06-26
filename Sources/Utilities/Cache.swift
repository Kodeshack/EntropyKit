
protocol CacheProtocol {
    /**
     Type that represents the values inside of the cache.
     */
    associatedtype V

    /**
     Returns the value associated with a given key.

     - Parameter key: An object identifying the value.
     - Parameter meta: Any object that can be used to give further clues about how to retrieve the data from the cache.

     - returns: The value associated with key, or nil if no value is associated with key.
     */
    func get(_ key: String, meta: Any?) -> V?

    /**
     Sets the value of the specified key in the cache, and associates the key-value pair with the
     specified cost.

     - Parameter key: The key with which to associate the value.
     - Parameter obj: The object to store in the cache.
     - Parameter cost: The cost with which to associate the key-value pair.

     ### Discussion
     The `cost` value is used to compute a sum encompassing the costs of all the objects in the
     cache. When memory is limited or when the total cost of the cache eclipses the maximum
     allowed total cost, the cache could begin an eviction process to remove some of its
     elements. However, this eviction process is not in a guaranteed order. As a consequence,
     if you try to manipulate the cost values to achieve some specific behavior, the
     consequences could be detrimental to your program. Typically, the obvious cost is the size
     of the value in bytes. If that information is not readily available, you should not go
     through the trouble of trying to compute it, as doing so will drive up the cost of using
     the cache. Pass in `0` for the cost value if you otherwise have nothing useful to pass.
     Unlike an `NSMutableDictionary` object, a cache does not copy the key objects that
     are put into it.
     */
    func set(_ key: String, object: V?, cost: Int)

    /**
     Removes the value of the specified key in the cache.

     - Parameter key: The key identifying the value to be removed.
     */
    func remove(_ key: String)

    /**
     Empties the cache.
     */
    func clear()

    /**
     Returns the value associated with a given key.

     - Parameter key: An object identifying the value.

     - returns: The value associated with key, or nil if no value is associated with key.
     */
    subscript(_: String) -> V? { get set }

    /**
     Returns the value associated with a given key.

     - Parameter key: An object identifying the value.
     - Parameter meta: Any object that can be used to give further clues about how to retrieve the data from the cache.

     - returns: The value associated with key, or nil if no value is associated with key.
     */
    subscript(_: String, _: Any?) -> V? { get set }

    /**
     Sets the value of the specified key in the cache, and associates the key-value pair with the
     specified cost.

     - Parameter key: The key with which to associate the value.
     - Parameter cost: The cost with which to associate the key-value pair.
     */
    subscript(_: String, _: Int) -> V? { get set }
}

class Cache<V>: CacheProtocol {
    func get(_: String, meta _: Any? = nil) -> V? {
        return nil
    }

    func set(_: String, object _: V?, cost _: Int = 0) {}
    func clear() {}
    func remove(_: String) {}

    subscript(key: String) -> V? {
        get {
            return get(key)
        }
        set {
            `set`(key, object: newValue)
        }
    }

    subscript(key: String, meta: Any?) -> V? {
        get {
            return get(key, meta: meta)
        }
        set {
            `set`(key, object: newValue)
        }
    }

    subscript(key: String, cost: Int) -> V? {
        get {
            return get(key)
        }
        set {
            `set`(key, object: newValue, cost: cost)
        }
    }
}
