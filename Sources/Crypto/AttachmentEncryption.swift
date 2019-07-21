import CommonCrypto

class AttachmentEncryption {
    enum AttachmentEncryptionError: Error {
        case secRandomCopyBytesFailed(code: Int32)
        case createCryptorFailed(code: Int32)
        case updateCryptorFailed(code: Int32)
        case sha256Mismatch
        case invalidIVData
        case invalidKeyData
        case unknownAlgorithm
    }

    struct EncryptedAttachmentData {
        let ciphertext: Data
        let info: EncryptedAttachment
    }

    private static func generateIVForAES256() -> Result<Data, Error> {
        // FROM https://github.com/matrix-org/matrix-ios-sdk/blob/v0.11.1/MatrixSDK/Crypto/Data/MXEncryptedAttachments.m#L86
        // Yes, we really generate half a block size worth of random data to put in the IV.
        // This is leave the lower bits (which they are because AES is defined to work in
        // big endian) of the IV as 0 (which it is because [NSMutableData initWithLength] gives
        // a zeroed buffer) to avoid the counter overflowing. This is because CommonCrypto's
        // counter wraps at 64 bits, but android's wraps at the full 128 bits, making them
        // incompatible if the IV wraps around. We fix this by madating that the lower order
        // bits of the IV are zero, so the counter will only wrap if the file is 2^64 bytes.
        var iv = Data(count: kCCBlockSizeAES128)

        let status = iv.withUnsafeMutableBytes { bytes -> Int32 in
            SecRandomCopyBytes(kSecRandomDefault, kCCBlockSizeAES128 / 2, bytes.baseAddress!)
        }

        if status != errSecSuccess {
            return .failure(AttachmentEncryptionError.secRandomCopyBytesFailed(code: status))
        }

        return .success(iv)
    }

    private static func generateKeyForAES256() -> Result<Data, Error> {
        var key = Data(count: kCCKeySizeAES256)
        let status = key.withUnsafeMutableBytes { bytes -> Int32 in
            SecRandomCopyBytes(kSecRandomDefault, kCCKeySizeAES256, bytes.baseAddress!)
        }

        if status != errSecSuccess {
            return .failure(AttachmentEncryptionError.secRandomCopyBytesFailed(code: status))
        }

        return .success(key)
    }

    private static func digestData(cryptor: CCCryptor, inputData: Data, sha256Hasher: SHA256, encrypting: Bool) -> Result<Data, Error> {
        var outputData = Data(capacity: inputData.count)
        var outputBuffer = Data(count: inputData.count)
        return Result {
            try inputData.withUnsafeBytes { inputBytes throws -> Void in
                let outputBufferLength = outputBuffer.count
                try outputBuffer.withUnsafeMutableBytes { outputBytes throws -> Void in
                    let bytesMoved = try cryptor.update(dataIn: inputBytes.baseAddress!, dataInLength: inputData.count, dataOut: outputBytes.baseAddress!, dataOutAvailable: outputBufferLength).get()

                    let outputBytesBase = outputBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    outputData.append(outputBytesBase, count: bytesMoved)
                    if encrypting {
                        sha256Hasher.update(data: outputBytes.baseAddress!, length: bytesMoved)
                    } else {
                        sha256Hasher.update(data: inputBytes.baseAddress!, length: bytesMoved)
                    }
                }
            }
            return outputData
        }
    }

    // Adapted and ported from https://github.com/matrix-org/matrix-ios-sdk/blob/v0.11.1/MatrixSDK/Crypto/Data/MXEncryptedAttachments.m#L72
    static func encrypt(plainData: Data, mimeType: String) -> Result<EncryptedAttachmentData, Error> {
        return Result {
            let iv = try generateIVForAES256().get()
            let key = try generateKeyForAES256().get()
            let cryptor = try CCCryptor(operation: .encrypt, iv: iv, key: key)
            let sha256Hasher = SHA256()

            let ciphertext = try digestData(cryptor: cryptor, inputData: plainData, sha256Hasher: sha256Hasher, encrypting: true).get()

            let attachmentInfo = EncryptedAttachment(
                mimeType: mimeType,
                size: ciphertext.count,
                iv: iv,
                key: key,
                sha256Hash: sha256Hasher.finalize()
            )

            return EncryptedAttachmentData(
                ciphertext: ciphertext,
                info: attachmentInfo
            )
        }
    }

    static func decrypt(ciphertext: Data, info: Attachment.Info.CryptoInfo) -> Result<Data, Error> {
        return Result {
            guard info.algorithm == .A256CTR else {
                throw AttachmentEncryptionError.unknownAlgorithm
            }

            guard info.initializationVector.count == kCCBlockSizeAES128 else {
                throw AttachmentEncryptionError.invalidIVData
            }

            guard info.key.count == kCCKeySizeAES256 else {
                throw AttachmentEncryptionError.invalidKeyData
            }

            let cryptor = try CCCryptor(operation: .decrypt, iv: info.initializationVector, key: info.key)
            let sha256Hasher = SHA256()

            let plainData = try digestData(cryptor: cryptor, inputData: ciphertext, sha256Hasher: sha256Hasher, encrypting: false).get()

            let sha256Data = Base64.unpadBase64(sha256Hasher.finalize().base64EncodedString())

            if sha256Data != info.sha256 {
                throw AttachmentEncryptionError.sha256Mismatch
            }

            return plainData
        }
    }
}
