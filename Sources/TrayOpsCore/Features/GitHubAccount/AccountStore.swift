import Foundation

/// Validation failures when persisting an account.
public enum AccountValidationError: Error, Equatable {
    case emptyField(String)
}

/// Persistence boundary for accounts (RN-GH-05/06). Hides the storage mechanism
/// from the rest of the domain.
public protocol AccountStore {
    func all() throws -> [Account]
    func add(_ account: Account) throws
    func update(_ account: Account) throws
    func remove(_ account: Account) throws
    /// Loads the seed accounts on first run when the store is empty; starts empty
    /// (without failing) when no valid seed source is available.
    func seedIfEmpty(from seedURL: URL?) throws
}

/// Local JSON-file account store with atomic writes. Chosen over SwiftData because
/// the `@Model` macro requires Xcode, which this project does not use. Adequate
/// for the handful of account records the platform manages.
public final class JSONAccountStore: AccountStore {
    private struct AccountsFile: Codable {
        var accounts: [Account]
    }

    private let url: URL
    private let lock = NSLock()
    private var accounts: [Account]

    public init(url: URL) {
        self.url = url
        self.accounts = JSONAccountStore.load(from: url)
    }

    public func all() throws -> [Account] {
        lock.lock()
        defer { lock.unlock() }
        return accounts.sorted { ($0.sortIndex, $0.label) < ($1.sortIndex, $1.label) }
    }

    public func add(_ account: Account) throws {
        try validate(account)
        lock.lock()
        defer { lock.unlock() }
        accounts.append(account)
        try persistLocked()
    }

    public func update(_ account: Account) throws {
        try validate(account)
        lock.lock()
        defer { lock.unlock() }
        var updated = account
        updated.updatedAt = Date()
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = updated
        } else {
            accounts.append(updated)
        }
        try persistLocked()
    }

    public func remove(_ account: Account) throws {
        lock.lock()
        defer { lock.unlock() }
        accounts.removeAll { $0.id == account.id }
        try persistLocked()
    }

    public func seedIfEmpty(from seedURL: URL?) throws {
        lock.lock()
        defer { lock.unlock() }
        guard accounts.isEmpty else { return }
        guard let seedURL, let entries = AccountSeed.load(from: seedURL) else { return }
        accounts = entries.enumerated().map { index, entry in
            Account(
                label: entry.label,
                gitName: entry.gitName,
                gitEmail: entry.gitEmail,
                identityFile: entry.identityFile,
                sortIndex: index
            )
        }
        try persistLocked()
    }

    // MARK: - Private

    private func validate(_ account: Account) throws {
        try requireNonEmpty(account.label, "label")
        try requireNonEmpty(account.gitName, "gitName")
        try requireNonEmpty(account.gitEmail, "gitEmail")
        try requireNonEmpty(account.identityFile, "identityFile")
    }

    private func requireNonEmpty(_ value: String, _ field: String) throws {
        if value.trimmingCharacters(in: .whitespaces).isEmpty {
            throw AccountValidationError.emptyField(field)
        }
    }

    /// Must be called with `lock` held.
    private func persistLocked() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(AccountsFile(accounts: accounts))
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: [.atomic])
    }

    private static func load(from url: URL) -> [Account] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(AccountsFile.self, from: data))?.accounts ?? []
    }
}
