protocol CryptoEngineDelegate: class {
    /// Called once when the crypto engine has been initialised.
    func handleError(_ sender: CryptoEngine, _ error: Error)
    #if DEBUG
        func hasStartedWork(_ sender: CryptoEngine)
        func hasFinishedWork(_ sender: CryptoEngine)
    #endif
}
