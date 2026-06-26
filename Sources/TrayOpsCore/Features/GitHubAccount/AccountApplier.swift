import Foundation

/// Applies an account's identity. Used by **both** Set and Reconcile so they
/// share exactly the same sequence (RN-GH-10): git first, then ssh; a git
/// failure aborts before touching ssh (RN-GH-09).
public protocol AccountApplier {
    func apply(_ account: Account) async throws
}

public struct DefaultAccountApplier: AccountApplier {
    private let git: GitConfigService
    private let ssh: SSHConfigService
    private let host: String

    public init(git: GitConfigService, ssh: SSHConfigService, host: String) {
        self.git = git
        self.ssh = ssh
        self.host = host
    }

    public func apply(_ account: Account) async throws {
        try await git.setIdentity(name: account.gitName, email: account.gitEmail)
        try await ssh.activateIdentity(path: account.identityFile, host: host)
    }
}
