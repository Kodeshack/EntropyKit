
public enum Result<T> {
    case Error(Error)
    case Value(T)

    public init(_ block: () throws -> T) {
        do {
            self = .Value(try block())
        } catch {
            self = .Error(error)
        }
    }

    public var isError: Bool {
        if case .Error = self {
            return true
        }
        return false
    }

    public var isValue: Bool {
        if case .Value = self {
            return true
        }
        return false
    }

    public var value: T? {
        if case let .Value(value) = self {
            return value
        }
        return nil
    }

    public var error: Error? {
        if case let .Error(error) = self {
            return error
        }
        return nil
    }

    public func dematerialize() throws -> T {
        switch self {
        case let .Value(value):
            return value
        case let .Error(error):
            throw error
        }
    }
}
