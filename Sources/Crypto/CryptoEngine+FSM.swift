extension CryptoEngine {
    enum State {
        case uninitialised
        case accountCreated
        case uploadedPublicAndOTKs
        case ready
        case fatalError
        case needToEncrypt
        case claimedDeviceOTKs
        case createdOutboundMegOLMSession
    }

    enum Transition {
        case createAccount(() -> State)
        case uploadPublicAndOTKs(() -> (State, CryptoEngineTask))
        case load(Database, (Database) -> (State, CryptoEngineTask))
        case encrypt((Event, RoomID, (Result<Event>) -> Void), ((Event, RoomID, (Result<Event>) -> Void)) -> (State, CryptoEngineTask))
        case encryptEvent((Event, RoomID, (Result<Event>) -> Void), ((Event, RoomID, (Result<Event>) -> Void)) -> State)
        case claimDeviceOTKs(RoomID, (RoomID) -> (State, CryptoEngineTask))
        case createOutboundMegOLMSession(RoomID, (RoomID) -> (State, CryptoEngineTask))
        case publishOutboundMegOLMSession(RoomID, (RoomID) -> State)
        case decrypt((Event, RoomID, (Result<Event>) -> Void), ((Event, RoomID, (Result<Event>) -> Void)) -> State)
        case decryptToDeviceEvent((SyncResponse.ToDeviceEvent, (Result<SyncResponse.ToDeviceEvent>) -> Void), ((SyncResponse.ToDeviceEvent, (Result<SyncResponse.ToDeviceEvent>) -> Void)) -> State)
        case roomKey(SyncResponse.ToDeviceEvent, (SyncResponse.ToDeviceEvent) -> State)
        case devicesChanged([UserID], ([UserID]) -> State)
        case memberChange((UserID, MemberJSON.Membership), ((UserID, MemberJSON.Membership)) -> (State, CryptoEngineTask))
        case otkCountChange(UInt, (UInt) -> State)

        case fatalError(Error, (Error) -> State)

        func exec() -> (State, CryptoEngineTask) {
            switch self {
            case let .createAccount(function):
                return (function(), .none)
            case let .uploadPublicAndOTKs(function):
                return function()
            case let .load(input, function):
                return function(input)
            case let .encrypt(input, function):
                return function(input)
            case let .encryptEvent(input, function):
                return (function(input), .none)
            case let .claimDeviceOTKs(input, function):
                return function(input)
            case let .createOutboundMegOLMSession(input, function):
                return function(input)
            case let .publishOutboundMegOLMSession(input, function):
                return (function(input), .none)
            case let .decrypt(input, function):
                return (function(input), .none)
            case let .decryptToDeviceEvent(input, function):
                return (function(input), .none)
            case let .roomKey(input, function):
                return (function(input), .none)
            case let .devicesChanged(input, function):
                return (function(input), .none)
            case let .memberChange(input, function):
                return function(input)
            case let .otkCountChange(input, function):
                return (function(input), .none)
            case let .fatalError(input, function):
                return (function(input), .none)
            }
        }
    }

    enum CryptoEngineTask {
        case none
        case createAccount
        case error(Error)
        case roomID(RoomID)
        case event(event: Event, roomID: RoomID, cb: (Result<Event>) -> Void)
        case roomKeyEvent(event: SyncResponse.ToDeviceEvent)
        case encryptedEvent(event: Event, roomID: RoomID, cb: (Result<Event>) -> Void)
        case encryptedToDeviceEvent(event: SyncResponse.ToDeviceEvent, cb: (Result<SyncResponse.ToDeviceEvent>) -> Void)
        case load(db: Database)
        case devicesChanged(userIDs: [UserID])
        case memberChange(userID: UserID, change: MemberJSON.Membership)
        case otkCountUpdate(UInt)
        case announceSession(roomID: RoomID)
    }
}
