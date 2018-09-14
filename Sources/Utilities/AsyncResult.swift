
public final class AsyncResult<T> {
    public enum State {
        case unresolved
        case resolved
        case cancelled
        case errored
    }

    public var state: State = .unresolved
    public var value: T?
    public var error: Error?

    private var successHandlers = [(T) -> Void]()
    private var errorHandlers = [(Error) -> Void]()

    public init() {

    }

    public init(_ immediate: () throws -> T) {
        do {
            value = try immediate()
            state = .resolved
        } catch let error {
            state = .errored
            self.error = error
        }
    }

    public init(value: T) {
        self.value = value
        state = .resolved
    }

    public init(error: Error) {
        state = .errored
        self.error = error
    }

    public init(async: () throws -> AsyncResult<T>) {
        do {
            try async().then { value in
                self.resolve(with: value)
            }.catch { error in
                self.reject(with: error)
            }
        } catch let error {
            state = .errored
            self.error = error
        }
    }

    static public func from(result: Result<T>) -> AsyncResult<T> {
        switch result {
            case .Value(let value):
                return AsyncResult<T>(value: value)
            case .Error(let error):
                return AsyncResult<T>(error: error)
        }
    }

    public func resolveOrReject(using result: Result<T>) {
        switch result {
        case .Value(let value):
            resolve(with: value)
        case .Error(let error):
            reject(with: error)
        }
    }

    public func resolve(with result: T) {
        guard state == .unresolved else { return }
        state = .resolved
        value = result
        successHandlers.forEach { handler in
            handler(result)
        }
        successHandlers.removeAll()
        errorHandlers.removeAll()
    }

    public func reject(with error: Error) {
        guard state == .unresolved else { return }
        state = .errored
        self.error = error
        errorHandlers.forEach { handler in
            handler(error)
        }
        successHandlers.removeAll()
        errorHandlers.removeAll()
    }

    public func cancel() {
        guard state == .unresolved else { return }
        state = .cancelled
        successHandlers.removeAll()
        errorHandlers.removeAll()
    }

    @discardableResult
    public func then<K>(_ block: @escaping (T) throws -> K) -> AsyncResult<K> {
        let nextResult = AsyncResult<K>()

        let resolver: (T) -> Void = { value in
            do {
                nextResult.resolve(with: try block(value))
            } catch let error {
                nextResult.reject(with: error)
            }
        }

        switch state {
        case .unresolved:
            successHandlers.append({ value in
                resolver(value)
            })
        case .resolved:
            resolver(value!)
        case .cancelled, .errored:
            break
        }

        return nextResult
    }

    public func then<K>(_ block: @escaping (T) throws -> AsyncResult<K>) -> AsyncResult<K> {
        let nextResult = AsyncResult<K>()

        let resolver: (T) -> Void = { value in
            do {
                let nextValue = try block(value)
                nextValue.then { nv in
                    nextResult.resolve(with: nv)
                }
            } catch let error {
                nextResult.reject(with: error)
            }
        }

        switch state {
        case .unresolved:
            successHandlers.append({ value in
                resolver(value)
            })
        case .resolved:
            resolver(value!)
        case .cancelled, .errored:
            break
        }

        return nextResult
    }

    @discardableResult
    public func `catch`(_ block: @escaping (Error) -> Void) -> AsyncResult<T> {
        errorHandlers.append(block)
        return self
    }
}
