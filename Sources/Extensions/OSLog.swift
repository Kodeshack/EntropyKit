import os.log

extension OSLog {
    public func log(_ message: String, type: OSLogType, error: Error? = nil) {
        if type == .error, let error = error {
            os_log("%@: %@", log: self, type: type, message as CVarArg, error.localizedDescription)
        } else {
            os_log("%@", log: self, type: type, message as CVarArg)
        }
    }
}
