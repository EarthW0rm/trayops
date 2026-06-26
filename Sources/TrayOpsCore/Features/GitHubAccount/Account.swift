import Foundation

/// Persisted GitHub identity profile. Internal to the core — it never crosses the
/// Mediator boundary (``AccountDTO`` does). A value type persisted as JSON
/// (SwiftData's `@Model` macro is unavailable without Xcode on this machine).
public struct Account: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var label: String
    public var gitName: String
    public var gitEmail: String
    public var identityFile: String
    public var sortIndex: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        label: String,
        gitName: String,
        gitEmail: String,
        identityFile: String,
        sortIndex: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.gitName = gitName
        self.gitEmail = gitEmail
        self.identityFile = identityFile
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public extension Account {
    /// Boundary representation of this account.
    var dto: AccountDTO {
        AccountDTO(
            id: id,
            label: label,
            gitName: gitName,
            gitEmail: gitEmail,
            identityFile: identityFile
        )
    }
}
