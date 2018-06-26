import Foundation

class MemoryCache<Value>: Cache<Value> {
    /**
     The name of the cache.
     */
    var name: String {
        return cache.name
    }

    /**
     The maximum number of objects the cache should hold.

     ### Discussion
     If 0, there is no count limit. The default value is 0.
     This is not a strict limit — if the cache goes over the limit, an object in the cache
     could be evicted instantly, later, or possibly never, depending on the implementation details of the cache.
     */
    var countLimit: Int {
        get {
            return cache.countLimit
        }
        set(countLimit) {
            cache.countLimit = countLimit
        }
    }

    /**
     The maximum total cost that the cache can hold before it starts evicting objects.

     ### Discussion
     If `0`, there is no total cost limit. The default value is `0`
     When you add an object to the cache, you may pass in a specified cost for the object, such
     as the size in bytes of the object. If adding this object to the cache causes the cache’s
     total cost to rise above `totalCostLimit`, the cache may automatically evict objects until its
     total cost falls below `totalCostLimit`. The order in which the cache evicts objects is not
     guaranteed.
     This is not a strict limit, and if the cache goes over the limit, an object in the cache
     could be evicted instantly, at a later point in time, or possibly never, all depending on
     the implementation details of the cache.
     */
    var totalCostLimit: Int {
        get {
            return cache.totalCostLimit
        }
        set(totalCostLimit) {
            cache.totalCostLimit = totalCostLimit
        }
    }

    private let cache = NSCache<NSString, AnyObject>()

    init(name: String = "", countLimit: Int = 0, totalCostLimit: Int = 0) {
        super.init()
        self.countLimit = countLimit
        self.totalCostLimit = totalCostLimit
        cache.name = name
    }

    private func convertTypes(_ value: Value?) -> AnyObject {
        switch value {
        case let str as NSString:
            return str
        case let num as NSNumber:
            return num
        default:
            return value as AnyObject
        }
    }

    /**
     Returns the value associated with a given key.

     - Parameter key: An object identifying the value.
     - Parameter meta: Any object that can be used to give further clues about how to retrieve the data from the cache.

     - returns: The value associated with key, or nil if no value is associated with key.
     */
    override func get(_ key: String, meta _: Any? = nil) -> Value? {
        return cache.object(forKey: key as NSString) as? Value
    }

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
    override func set(_ key: String, object: Value?, cost: Int = 0) {
        cache.setObject(convertTypes(object), forKey: key as NSString, cost: cost)
    }

    /**
     Removes the value of the specified key in the cache.

     - Parameter key: The key identifying the value to be removed.
     */
    override func remove(_ key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    /**
     Empties the cache.
     */
    override func clear() {
        cache.removeAllObjects()
    }
}
