import Foundation

/// Resolve the current GitHub account state.
public struct ResolveGitHubState: Request {
    public typealias Output = GitHubAccountState
    public init() {}
}

/// List the registered accounts.
public struct ListAccounts: Request {
    public typealias Output = [AccountDTO]
    public init() {}
}

/// Apply (Set) an account by id.
public struct ApplyAccount: Request {
    public typealias Output = ApplyResultDTO
    public let id: UUID
    public init(id: UUID) { self.id = id }
}

/// Reconcile an account. When `id` is nil, the last applied (target) account is
/// reapplied (RN-GH-10).
public struct ReconcileAccount: Request {
    public typealias Output = ApplyResultDTO
    public let id: UUID?
    public init(id: UUID? = nil) { self.id = id }
}

/// Create a new account.
public struct AddAccount: Request {
    public typealias Output = AccountDTO
    public let label: String
    public let gitName: String
    public let gitEmail: String
    public let identityFile: String
    public init(label: String, gitName: String, gitEmail: String, identityFile: String) {
        self.label = label
        self.gitName = gitName
        self.gitEmail = gitEmail
        self.identityFile = identityFile
    }
}

/// Update an existing account.
public struct UpdateAccount: Request {
    public typealias Output = AccountDTO
    public let id: UUID
    public let label: String
    public let gitName: String
    public let gitEmail: String
    public let identityFile: String
    public init(id: UUID, label: String, gitName: String, gitEmail: String, identityFile: String) {
        self.id = id
        self.label = label
        self.gitName = gitName
        self.gitEmail = gitEmail
        self.identityFile = identityFile
    }
}

/// Remove an account by id.
public struct RemoveAccount: Request {
    public typealias Output = Void
    public let id: UUID
    public init(id: UUID) { self.id = id }
}

public enum GitHubAccountError: Error, Equatable {
    case accountNotFound
    case noTargetAccount
}

/// Mutable holder for the last applied account, shared between the apply/reconcile
/// handlers and the Feature's `reconcile()` (used by Reconcile All).
///
/// This is a side channel concurrently accessed by the 15s state poller and by
/// `apply`/`reconcile` operations. Access to the backing `_id` is serialized by an
/// internal `NSLock` to avoid a data race between those paths; the class is therefore
/// `@unchecked Sendable` because the synchronization is performed manually rather than
/// guaranteed by the compiler.
public final class AccountTarget: @unchecked Sendable {
    private let lock = NSLock()
    private var _id: UUID?

    public var id: UUID? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _id
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _id = newValue
        }
    }

    public init(id: UUID? = nil) { self._id = id }
}
