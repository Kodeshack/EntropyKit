import GRDB

protocol Store {
    associatedtype T: Record
    init(database: Database)
    func fetchAll() -> [T]
    func fetch(key: String) -> Result<T?>
    func save(_ record: T) -> Result<T>
    func delete(_ record: T) -> Result<Void>
}
