import Foundation
import os.log

class FileCache<Value>: Cache<Value> {
    /**
     The name of the cache.
     */
    let name: String

    private let queue: DispatchQueue

    private let tmpDir: URL

    private let transformForCache: (Value?) -> Data
    private let transformFromCache: (Data) -> Value?

    private let logger: OSLog

    var delegate: FileCacheDelegate?

    init(
        name: String = NSUUID().uuidString,
        queue: DispatchQueue = DispatchQueue.main,
        transformForCache: @escaping (Value?) -> Data,
        transformFromCache: @escaping (Data?) -> Value?
    ) throws {
        self.name = name

        self.queue = queue

        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                name,
                isDirectory: true
            )

        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        self.transformForCache = transformForCache
        self.transformFromCache = transformFromCache

        // @TODO: make turn-off-able
        logger = OSLog(subsystem: "Bundle.main.bundleIdentifier", category: "FileCache")
    }

    /**
     Returns the value associated with a given key.

     - Parameter key: An object identifying the value.

     - returns: The value associated with key, or nil if no value is associated with key.
     */
    override func get(_ key: String, meta _: Any? = nil) -> Value? {
        let url = tmpDir.appendingPathComponent(key)

        if FileManager.default.fileExists(at: url) {
            if let data = try? NSData(contentsOf: url) as Data {
                return transformFromCache(data)
            }
        }

        return nil
    }

    /**
     Sets the value of the specified key in the cache, and associates the key-value pair with the
     specified cost.

     - Parameter key: The key with which to associate the value.
     - Parameter obj: The object to store in the cache.
     - Parameter cost: currently unused
     */
    override func set(_ key: String, object: Value?, cost _: Int = 0) {
        let data = transformForCache(object)
        queue.async {
            do {
                try data.write(to: self.tmpDir.appendingPathComponent(key), options: .atomicWrite)
                self.delegate?.wroteCacheFile(self, key: key, value: object)
            } catch {
                self.logger.log("Error while trying to write cache file", type: .error, error: error)
            }
        }
    }

    /**
     Removes the value of the specified key in the cache.

     - Parameter key: The key identifying the value to be removed.
     */
    override func remove(_ key: String) {
        do {
            try FileManager.default.removeItem(at: tmpDir.appendingPathComponent(key))
        } catch {
            logger.log("Error while trying to delete cache file", type: .error, error: error)
        }
    }

    /**
     Empties the cache.
     */
    override func clear() {
        do {
            // TODO: check async groups and possible race condition with writes.
            // We should cancel all writes to the directory when clearing.
            let files = try FileManager.default.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil)
            for file in files {
                try FileManager.default.removeItem(at: file)
            }
        } catch {
            logger.log("Error while trying to delete all cache files. Error: %@", type: .error, error: error)
        }
    }
}

protocol FileCacheDelegate: class {
    func wroteCacheFile<V>(_ cache: FileCache<V>, key: String, value: V?) -> Void
}
