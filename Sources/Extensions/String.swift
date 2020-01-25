import Foundation

extension String {
    public var isEmojiOnly: Bool {
        unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil
    }

    /// All the urls and their corresponding ranges contained in this String.
    public var urls: [(url: URL, range: NSRange)] {
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector.matches(in: self, options: .reportCompletion, range: NSMakeRange(0, count))
        return matches.compactMap { match in
            if let url = match.url {
                return (url, match.range)
            }
            return nil
        }
    }

    /// Converts a HTML-String to a String with replaced HTML-Entities. This function must be called from the main thread,
    /// because of `NSAttributedString` 🤷!
    ///
    /// - Returns: The unescaped String.
    #if canImport(AppKit)
        public func unescapingHTMLEntities() -> String {
            // @TODO: Add support for iOS.
            // Not sure whether this can fail.
            NSAttributedString(html: Data(utf8), options: [.characterEncoding: Encoding.utf8.rawValue], documentAttributes: nil)!.string
        }
    #endif
}
