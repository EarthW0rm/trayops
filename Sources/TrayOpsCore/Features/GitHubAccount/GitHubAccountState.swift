import Foundation

/// State of the GitHub Account Function: the active account correlated from two
/// signals (git `user.name` and the active SSH `IdentityFile`).
public enum GitHubAccountState: FeatureState, Equatable {
    /// git and ssh point to the same registered account.
    case consistent(AccountDTO)
    /// git and ssh diverge (or only one matches a registered account).
    case inconsistent(git: AccountDTO?, ssh: AccountDTO?)
    /// No signal matches any registered account.
    case unknown
    /// The Function could not compute its state (e.g. git binary absent).
    case unavailable(reason: String)

    /// Human-readable one-line summary shared by the GUI and the CLI.
    public var summary: String {
        switch self {
        case .consistent(let account):
            return "Consistent: \(account.label)"
        case .inconsistent(let git, let ssh):
            return "Inconsistent (git: \(git?.label ?? "—"), ssh: \(ssh?.label ?? "—"))"
        case .unknown:
            return "Unknown account"
        case .unavailable(let reason):
            return "Unavailable: \(reason)"
        }
    }
}

/// Result of applying (Set) or reconciling an account.
public struct ApplyResultDTO: Sendable, Equatable {
    public let success: Bool
    public let message: String?
    public let state: GitHubAccountState

    public init(success: Bool, message: String?, state: GitHubAccountState) {
        self.success = success
        self.message = message
        self.state = state
    }
}
