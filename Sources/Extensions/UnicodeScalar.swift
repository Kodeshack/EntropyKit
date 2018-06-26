extension UnicodeScalar {
    public var isEmoji: Bool {
        // 0x3030, 0x00AE, 0x00A9 // Special Characters
        // 0x2100 ... 0x27BF      // Misc symbols and Dingbats
        switch value {
        case 0x1D000 ... 0x1F77F, // Emoticons
             0xFE00 ... 0xFE0F, // Variation Selectors
             0x1F900 ... 0x1F9FF: // Supplemental Symbols and Pictographs
            return true
        case 0x2640, 0x2642: // gender signs
            return true
        default:
            return false
        }
    }

    public var isZeroWidthJoiner: Bool {
        return value == 8205
    }
}
