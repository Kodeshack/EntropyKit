import CommonCrypto

/// Minimalistic wrapper only to be used with AES256 crypto for now. Could be extended later.
class CCCryptor {
    /// Taken from https://opensource.apple.com/source/CommonCrypto/CommonCrypto-36064/CommonCrypto/CommonCryptor.h
    enum CryptorStatus: Int32, Error {
        case success = 0
        case parameterError = -4300
        case bufferTooSmall = -4301
        case memoryFailure = -4302
        case alignmentError = -4303
        case decodeError = -4304
        case unimplemented = -4305
        case overflow = -4306
    }

    enum CCCryptorOperation {
        case encrypt
        case decrypt

        var raw: CCOperation {
            switch self {
            case .encrypt:
                return CCOperation(kCCEncrypt)
            case .decrypt:
                return CCOperation(kCCDecrypt)
            }
        }
    }

    private var reference: CCCryptorRef?
    private var bytesMoved = 0

    init(operation: CCCryptorOperation, iv: Data, key: Data) throws {
        let statusCode = iv.withUnsafeBytes { (ivBytes: UnsafePointer<Int8>) -> CCCryptorStatus in
            key.withUnsafeBytes { (keyBytes: UnsafePointer<Int8>) -> CCCryptorStatus in
                CCCryptorCreateWithMode(
                    operation.raw,
                    CCMode(kCCModeCTR),
                    CCAlgorithm(kCCAlgorithmAES),
                    CCPadding(ccNoPadding),
                    ivBytes,
                    keyBytes,
                    kCCKeySizeAES256,
                    nil, 0, 0,
                    CCModeOptions(kCCModeOptionCTR_BE),
                    &reference
                )
            }
        }

        let status = CryptorStatus(rawValue: statusCode)!

        guard status == .success else {
            throw status
        }
    }

    deinit {
        CCCryptorRelease(reference)
    }

    /// Read data from the dataIn buffer for dataInLength bytes and put the encrypted content into
    /// the dataOut buffer. Please see the docs for CCCryptorUpdate (if you can find them...) for more info.
    ///
    /// - Parameters:
    ///   - dataIn: Buffer containing the data to be encrypted.
    ///   - dataInLength: Number of bytes to read from the dataIn buffer.
    ///   - dataOut: Buffer to which the encrypted data will be written.
    ///   - dataOutAvailable: The size of the dataOut buffer in bytes.
    /// - Returns: The number of bytes that were "moved" from the input to the output buffer.
    func update(dataIn: UnsafePointer<UInt8>, dataInLength: Int, dataOut: UnsafeMutablePointer<UInt8>, dataOutAvailable: Int) -> Result<Int> {
        let statusCode = CCCryptorUpdate(reference, dataIn, dataInLength, dataOut, dataOutAvailable, &bytesMoved)
        let status = CryptorStatus(rawValue: statusCode)!

        guard status == .success else {
            return .Error(status)
        }

        return .Value(bytesMoved)
    }
}
