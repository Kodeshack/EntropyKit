import Foundation

extension Bundle {
    public var displayName: String {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as! String
    }

    public var shortVersion: String {
        return object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    }

    public var bundleIdentifier: String {
        return object(forInfoDictionaryKey: "CFBundleIdentifier") as! String
    }

    public var applicationName: String {
        return object(forInfoDictionaryKey: "CFBundleName") as! String
    }

    public var copyright: String {
        return object(forInfoDictionaryKey: "NSHumanReadableCopyright") as! String
    }
}
