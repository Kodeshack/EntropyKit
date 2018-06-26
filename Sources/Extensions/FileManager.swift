import Foundation

extension FileManager {
    public func fileExists(at url: URL) -> Bool {
        return fileExists(atPath: url.path)
    }
}
