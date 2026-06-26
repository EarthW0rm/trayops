import Foundation

/// Boundary representation of an account. Carries no SwiftData dependency, so it
/// can safely cross the Mediator boundary to the frontends.
public struct AccountDTO: Sendable, Identifiable, Equatable {
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
