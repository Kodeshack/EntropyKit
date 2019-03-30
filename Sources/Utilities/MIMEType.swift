#if canImport(MobileCoreServices)
    import MobileCoreServices
#endif

class MIMEType {
    static let unknown = "application/octet-stream"

    // https://en.wikipedia.org/wiki/List_of_file_signatures
    static func mime(for data: Data) -> String {
        guard data.count >= 2 else {
            return MIMEType.unknown
        }

        var magicNumber: UInt16 = 0
        data.withUnsafeBytes { bytes in
            magicNumber = bytes.load(as: UInt16.self)
        }

        switch magicNumber {
        case 0xD8FF:
            return "image/jpeg"
        case 0x5089:
            return "image/png"
        case 0x4947:
            return "image/gif"
        case 0x4949, 0x4D4D:
            return "image/tiff"
        case 0x5025:
            return "application/pdf"
        case 0x4F46:
            return "text/plain"
        default:
            return MIMEType.unknown
        }
    }

    // See: https://medium.com/@francishart/swift-how-to-determine-file-type-4c46fc2afce8
    // Also: http://blog.ablepear.com/2010/08/how-to-get-file-extension-for-mime-type.html
    // Reference: https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/UTIRef/Articles/System-DeclaredUniformTypeIdentifiers.html
    // For info on Unmanaged: https://nshipster.com/unmanaged/
    static func mime(for fileExtension: String) -> String {
        // This returns nil if the file extension is not recognised
        guard let extUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension as CFString, nil) else {
            return MIMEType.unknown
        }

        guard let mimeUTI = UTTypeCopyPreferredTagWithClass(extUTI.takeUnretainedValue(), kUTTagClassMIMEType) else {
            return MIMEType.unknown
        }

        return String(mimeUTI.takeUnretainedValue())
    }

    static func fileExtension(for mime: String) -> String? {
        // This returns nil if the mime type is not recognised
        guard let mimeUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mime as CFString, nil) else {
            return nil
        }

        guard let extUTI = UTTypeCopyPreferredTagWithClass(mimeUTI.takeRetainedValue(), kUTTagClassFilenameExtension) else {
            return nil
        }

        return String(extUTI.takeUnretainedValue())
    }

    /// Best effort attempt to detect the mime type
    static func detectMIMEType(filename: String, data: Data) -> String {
        if let ext = URL(string: filename)?.pathExtension {
            let mime = MIMEType.mime(for: ext)
            return mime != MIMEType.unknown ? mime : MIMEType.mime(for: data)
        } else {
            return MIMEType.mime(for: data)
        }
    }

    private static func utTypeConformsTo(tagClass: CFString, identifier: String, conformTagClass: CFString) -> Bool {
        guard let uti = UTTypeCreatePreferredIdentifierForTag(tagClass, identifier as CFString, nil) else {
            return false
        }
        return UTTypeConformsTo(uti.takeUnretainedValue(), conformTagClass)
    }

    static func isImage(fileExtension: String) -> Bool {
        return utTypeConformsTo(tagClass: kUTTagClassFilenameExtension, identifier: fileExtension, conformTagClass: kUTTypeImage)
    }

    static func isImage(mime: String) -> Bool {
        return utTypeConformsTo(tagClass: kUTTagClassMIMEType, identifier: mime, conformTagClass: kUTTypeImage)
    }

    static func isAudio(fileExtension: String) -> Bool {
        return utTypeConformsTo(tagClass: kUTTagClassFilenameExtension, identifier: fileExtension, conformTagClass: kUTTypeAudio)
    }

    static func isAudio(mime: String) -> Bool {
        return utTypeConformsTo(tagClass: kUTTagClassMIMEType, identifier: mime, conformTagClass: kUTTypeAudio)
    }

    static func isMPEG4Video(fileExtension: String) -> Bool {
        return utTypeConformsTo(tagClass: kUTTagClassFilenameExtension, identifier: fileExtension, conformTagClass: kUTTypeMPEG4)
    }

    static func isMPEG4Video(mime: String) -> Bool {
        return utTypeConformsTo(tagClass: kUTTagClassMIMEType, identifier: mime, conformTagClass: kUTTypeMPEG4)
    }
}
