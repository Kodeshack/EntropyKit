import Foundation
import os.log

public class Scheduler {
    private let logger: OSLog?
    private let name: String
    private let interval: Int
    private var action: (@escaping () -> Void) -> Void
    private var active: Bool
    private let qos: DispatchQoS
    private let queue: DispatchQueue

    init(name: String, interval: Int, qos: DispatchQoS = .background) {
        self.name = name
        self.interval = interval
        self.qos = qos
        action = { _ in }
        logger = OSLog(subsystem: name, category: "Scheduler")
        active = false
        queue = DispatchQueue(label: name, qos: qos)
    }

    public func start(action: @escaping (@escaping () -> Void) -> Void) {
        self.action = action
        active = true
        schedule()
    }

    public func stop() {
        active = false
    }

    public func schedule() {
        guard active else {
            return
        }

        let when = DispatchTime.now() + DispatchTimeInterval.milliseconds(interval)

        logger?.log("[\(name)] next action scheduled for \(when)", type: .info)

        queue.asyncAfter(deadline: when) {
            self.logger?.log("[\(self.name)] firing action scheduled for \(when)", type: .info)
            self.action {
                self.schedule()
            }
        }
    }
}
