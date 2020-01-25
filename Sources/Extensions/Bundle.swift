import Foundation

extension Bundle {
    public var displayName: String {
        object(forInfoDictionaryKey: "CFBundleDisplayName") as! String
    }

    public var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    }

    public var bundleIdentifier: String {
        object(forInfoDictionaryKey: "CFBundleIdentifier") as! String
    }

    public var applicationName: String {
        object(forInfoDictionaryKey: "CFBundleName") as! String
    }

    public var copyright: String {
        object(forInfoDictionaryKey: "NSHumanReadableCopyright") as! String
    }
}
