import Foundation

/// Correlates the two signals (git `user.name` + active SSH `IdentityFile`)
/// against the registered accounts to classify the state (RN-GH-03/04).
public protocol AccountStateResolver {
    func resolve(accounts: [Account]) async throws -> GitHubAccountState
}

public struct DefaultAccountStateResolver: AccountStateResolver {
    private let git: GitConfigService
    private let ssh: SSHConfigService
    private let host: String

    public init(git: GitConfigService, ssh: SSHConfigService, host: String) {
        self.git = git
        self.ssh = ssh
        self.host = host
    }

    public func resolve(accounts: [Account]) async throws -> GitHubAccountState {
        let gitName: String?
        let activeIdentity: String?
        do {
            gitName = try await git.currentUserName()
            activeIdentity = try await ssh.activeIdentityFile(host: host)
        } catch GitConfigError.binaryNotFound {
            return .unavailable(reason: "git binary not found")
        } catch {
            return .unavailable(reason: "\(error)")
        }

        let gitMatch = gitName.flatMap { name in accounts.first { $0.gitName == name } }
        let sshMatch = activeIdentity.flatMap { identity in accounts.first { $0.identityFile == identity } }

        if gitMatch == nil, sshMatch == nil {
            return .unknown
        }
        if let gitMatch, let sshMatch, gitMatch.id == sshMatch.id {
            return .consistent(gitMatch.dto)
        }
        return .inconsistent(git: gitMatch?.dto, ssh: sshMatch?.dto)
    }
}
