#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#else
    #error("Can neither import UIKit nor AppKit, something's very wrong.")
#endif

import GRDB

public class ObservablePersistedList<T: Record> {
    private let database: Database
    private let recordsController: FetchedRecordsController<T>

    private var observerTokens = Set<ObserverToken>()
    private var counter = UInt(0)

    init(database: Database, sql: String, arguments: StatementArguments?, adapater: RowAdapter?, callbackQueue: DispatchQueue = DispatchQueue.main) throws {
        self.database = database
        recordsController = try FetchedRecordsController(database.dbQueue, sql: sql, arguments: arguments, adapter: adapater, queue: callbackQueue)
        try setup()
    }

    init(database: Database, request: QueryInterfaceRequest<T>, callbackQueue: DispatchQueue = DispatchQueue.main) throws {
        self.database = database
        recordsController = try FetchedRecordsController(database.dbQueue, request: request, queue: callbackQueue)
        try setup()
    }

    init(database: Database, callbackQueue: DispatchQueue = DispatchQueue.main) throws {
        self.database = database
        recordsController = try FetchedRecordsController(database.dbQueue, request: T.all(), queue: callbackQueue)
        try setup()
    }

    private func setup() throws {
        recordsController.trackChanges(
            willChange: { [unowned self] _ in
                self.observerTokens.forEach { $0.willChangeHandler() }
            },
            onChange: { [unowned self] _, record, change in
                self.observerTokens.forEach { $0.onChangeHandler(record, change) }
            },
            didChange: { [unowned self] _ in
                self.observerTokens.forEach { $0.didChangeHandler() }
            }
        )

        try recordsController.performFetch()
    }

    func changeRequest(_ request: QueryInterfaceRequest<T>) throws {
        try recordsController.setRequest(request)
        try recordsController.performFetch()
    }
}

// MARK: - Observable

extension ObservablePersistedList {
    public typealias Change = FetchedRecordChange
    public typealias WillChangeHandler = () -> Void
    public typealias OnChangeHandler = (_ record: T, _ change: Change) -> Void
    public typealias DidChangeHandler = () -> Void

    public class ObserverToken: Equatable, Hashable {
        public static func == (lhs: ObserverToken, rhs: ObserverToken) -> Bool {
            return lhs.id == rhs.id
        }

        public var hashValue: Int {
            return id.hashValue
        }

        let id: UInt
        let willChangeHandler: WillChangeHandler
        let onChangeHandler: OnChangeHandler
        let didChangeHandler: DidChangeHandler
        weak var owner: ObservablePersistedList?

        init(id: UInt, owner: ObservablePersistedList, willChangeHandler: @escaping WillChangeHandler, onChangeHandler: @escaping OnChangeHandler, didChangeHandler: @escaping DidChangeHandler) {
            self.id = id
            self.owner = owner
            self.willChangeHandler = willChangeHandler
            self.onChangeHandler = onChangeHandler
            self.didChangeHandler = didChangeHandler
        }

        public func invalidate() {
            owner?.removeObserver(token: self)
        }
    }

    func removeObserver(token: ObserverToken) {
        observerTokens.remove(token)
    }

    public func addObserver(willChange: @escaping WillChangeHandler, onChange: @escaping OnChangeHandler, didChange: @escaping DidChangeHandler) -> ObserverToken {
        let token = ObserverToken(id: counter, owner: self, willChangeHandler: willChange, onChangeHandler: onChange, didChangeHandler: didChange)
        observerTokens.insert(token)
        counter += 1
        return token
    }
}

// MARK: - TableView observer helper

extension ObservablePersistedList {
    #if canImport(UIKit)
        public func addObserver<V: UITableViewCell>(for tableView: UITableView, configureCell: @escaping (V, IndexPath) -> Void) -> ObserverToken {
            return addObserver(
                willChange: { [unowned tableView] in
                    tableView.beginUpdates()
                },
                onChange: { [unowned tableView] _, change in
                    switch change {
                    case let .insertion(indexPath):
                        tableView.insertRows(at: [indexPath], with: .fade)
                    case let .deletion(indexPath):
                        tableView.deleteRows(at: [indexPath], with: .fade)
                    case let .move(indexPath, newIndexPath, _):
                        tableView.moveRow(at: indexPath, to: newIndexPath)
                        if let cell = tableView.cellForRow(at: indexPath) as? V {
                            configureCell(cell, newIndexPath)
                        }
                    case let .update(indexPath, _):
                        if let cell = tableView.cellForRow(at: indexPath) as? V {
                            configureCell(cell, indexPath)
                        }
                    }
                },
                didChange: { [unowned tableView] in
                    tableView.endUpdates()
                }
            )
        }

    #elseif canImport(AppKit)
        public func addObserver<V: NSTableCellView>(for tableView: NSTableView, configureCell: @escaping (V, Int) -> Void) -> ObserverToken {
            return addObserver(
                willChange: { [unowned tableView] in
                    tableView.beginUpdates()
                },
                onChange: { [unowned tableView] _, change in
                    switch change {
                    case let .insertion(indexPath):
                        let row = IndexSet(arrayLiteral: indexPath.item)
                        tableView.insertRows(at: row, withAnimation: .effectFade)
                        tableView.noteHeightOfRows(withIndexesChanged: row)
                    case let .deletion(indexPath):
                        let row = IndexSet(arrayLiteral: indexPath.item)
                        tableView.removeRows(at: row, withAnimation: .effectFade)
                        tableView.noteHeightOfRows(withIndexesChanged: row)
                    case let .move(indexPath, newIndexPath, _):
                        tableView.moveRow(at: indexPath.item, to: newIndexPath.item)
                        if let cell = tableView.view(atColumn: indexPath.section, row: indexPath.item, makeIfNecessary: true) as? V {
                            configureCell(cell, newIndexPath.item)
                            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(arrayLiteral: indexPath.item))
                        }
                    case let .update(indexPath, _):
                        if let cell = tableView.view(atColumn: indexPath.section, row: indexPath.item, makeIfNecessary: true) as? V {
                            configureCell(cell, indexPath.item)
                            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(arrayLiteral: indexPath.item))
                        }
                    }
                },
                didChange: { [unowned tableView] in
                    tableView.endUpdates()
                }
            )
        }
    #endif
}

// MARK: - RandomAccessCollection

extension ObservablePersistedList: RandomAccessCollection {
    public func index(after i: Int) -> Int {
        return recordsController.fetchedRecords.index(after: i)
    }

    public var startIndex: Int {
        return recordsController.fetchedRecords.startIndex
    }

    public var endIndex: Int {
        return recordsController.fetchedRecords.endIndex
    }

    public subscript(key: Int) -> T {
        return recordsController.record(at: IndexPath(item: key, section: 0))
    }
}

// MARK: - Sequence

extension ObservablePersistedList: Sequence {}
