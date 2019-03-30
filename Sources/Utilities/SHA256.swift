import CommonCrypto

class SHA256 {
    private var context = CC_SHA256_CTX()

    init() {
        CC_SHA256_Init(&context)
    }

    func update(data: UnsafeRawPointer, length: Int) {
        CC_SHA256_Update(&context, data, CC_LONG(length))
    }

    func finalize() -> Data {
        var buffer = Data(count: Int(CC_SHA256_DIGEST_LENGTH))

        _ = buffer.withUnsafeMutableBytes { bytes in
            let md = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
            // According to https://opensource.apple.com/source/CommonCrypto/CommonCrypto-60118.30.2/lib/CommonDigest.c.auto.html
            // this will always be 1, so we just ignore it.
            CC_SHA256_Final(md, &context)
        }

        return buffer
    }
}
