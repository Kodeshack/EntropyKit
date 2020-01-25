import Foundation

extension FileManager {
    public func fileExists(at url: URL) -> Bool {
        fileExists(atPath: url.path)
    }
}
