import Foundation
import GRDB
import os.log

protocol SyncServiceDelegate: AnyObject {
    func syncStarted()
    func syncEnded(_ result: Result<SyncService.SyncResult>)
}

class SyncService {
    struct SyncResult {
        let nextBatch: String
        var events: [Event]
        let deviceEvents: [SyncResponse.ToDeviceEvent]
        let timestamp: Date
        /// Contains the list of user ids whose devices have changed (that's what we get from the API)
        let devicesChanged: [UserID]
        let otkCount: UInt?
    }

    var isSyncing: Bool
    var delegate: SyncServiceDelegate?

    private let logger: OSLog?
    private let timeout: Int
    private let account: Account

    private let database: Database
    private let dispatchQueue: DispatchQueue
    private let e2eeService: E2EEService

    init(account: Account, database: Database, timeout: Int = 5000) {
        self.account = account
        isSyncing = false
        self.timeout = timeout
        self.database = database
//       logger = OSLog(subsystem: Bundle.main.bundleIdentifier, category: "SyncService")
        logger = nil
        dispatchQueue = DispatchQueue(label: "DQ for \(account.userID) sync service", qos: .background)
        e2eeService = E2EEService(database: database)
    }

    private func transformResponse(_ syncResponse: SyncResponse) -> Result<SyncResult> {
        let roomEvents = syncResponse.rooms.join.flatMap { item -> [Event] in
            let roomID = item.key
            let joinedRoom = item.value

            var events = (joinedRoom.state.events + joinedRoom.timeline.events)

            events.append(Event(
                id: roomID + joinedRoom.timeline.prev_batch!, // a uniquish ID for filtering later on
                senderID: roomID,
                type: .roomPrevBatch,
                date: Date(),
                roomID: roomID,
                content: .roomPrevBatch(joinedRoom.timeline.prev_batch!)
            ))

            return events.map { event in
                var event = event
                event.roomID = roomID
                return event
            }
        }

        let decryptGroup = DispatchGroup()

        var deviceEvents = [SyncResponse.ToDeviceEvent]()

        syncResponse.toDevice.events.forEach { event in
            decryptGroup.enter()
            if case .encrypted = event.content {
                self.account.decrypt(toDeviceEvent: event) { decryptionResult in
                    defer { decryptGroup.leave() }

                    switch decryptionResult {
                    case let .Value(event):
                        deviceEvents.append(event)
                    case let .Error(error):
                        // @TODO: error handling
                        print(error)
                    }
                }
            } else {
                decryptGroup.leave()
                deviceEvents.append(event)
            }
        }

        decryptGroup.wait()

        let events = roomEvents

        return .Value(SyncResult(
            nextBatch: syncResponse.nextBatch,
            // deduplicate and ensure the order (events do actually come out of order!!)
            events: Set(events).sorted { $0.date! <= $1.date! },
            deviceEvents: NSOrderedSet(array: deviceEvents).array as! [SyncResponse.ToDeviceEvent],
            timestamp: Date(),
            devicesChanged: syncResponse.deviceLists.changed,
            otkCount: syncResponse.otkCount
        ))
    }

    func sync(completionHandler: @escaping () -> Void) {
        guard !isSyncing else {
            logger?.log("Trying to sync while a sync is already in progress", type: .fault)
            return
        }

        delegate?.syncStarted()
        logger?.log("started", type: .info)

        MatrixAPI.default.sync(timeout: timeout, nextBatch: account.nextBatch, accessToken: account.accessToken, queue: dispatchQueue) { syncResponseResult in
            self.logger?.log("response received", type: .info)

            guard let syncResponse = syncResponseResult.value else {
                self.logger?.log("syncResponseResult.error", type: .error, error: syncResponseResult.error)
                self.delegate?.syncEnded(.Error(syncResponseResult.error!))
                return
            }

            self.logger?.log("ended", type: .info)
            var result = self.transformResponse(syncResponse)

            switch result {
            case let .Error(error):
                self.logger?.log("after transform", type: .error, error: error)
            case let .Value(value):
                result = self.writeResultToDB(value)
                if value.events.first(where: { e in e.type == .encryption }) != nil {
                    self.e2eeService.announceDevice(account: self.account)
                }
            }

            self.delegate?.syncEnded(result)
            completionHandler()
        }
    }

    private func writeResultToDB(_ result: SyncResult) -> Result<SyncResult> {
        var result = result

        if !result.devicesChanged.isEmpty {
            account.devicesChanged(userIDs: result.devicesChanged)
        }

        result.deviceEvents.filter { $0.type == .roomKey }.forEach { event in
            self.account.roomKeyEvent(event: event)
        }

        let decryptGroup = DispatchGroup()

        result.events.filter { $0.type == .encrypted }.forEach { event in
            decryptGroup.enter()
            account.decrypt(event: event) { decryptResult in
                defer { decryptGroup.leave() }

                switch decryptResult {
                case let .Value(event):
                    result.events.append(event)
                case let .Error(error):
                    // @TODO: error handling
                    print(error)
                }
            }
        }

        decryptGroup.wait()

        do {
            try database.dbQueue.inTransaction { db in
                try result.events.forEach { event in
                    try event.persist(db).dematerialize()
                }

                DispatchQueue.main.sync {
                    self.account.nextBatch = result.nextBatch
                }

                try self.account.update(db)

                return .commit
            }
        } catch {
            print(error)
            logger?.log("while trying to save to the database", type: .error, error: error)
            return .Error(error)
        }

        result.events.filter { $0.type == .member }.forEach { event in
            account.memberChange(userID: event.senderID!, change: event.content.member!.membership)
        }

        if let otkCount = result.otkCount {
            account.updateOTKCount(otkCount)
        }

        return .Value(result)
    }
}
