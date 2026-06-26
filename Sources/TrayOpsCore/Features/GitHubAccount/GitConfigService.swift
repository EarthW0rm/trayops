import Foundation

/// Reads and writes the global git identity (RN-GH-01).
public protocol GitConfigService {
    func currentUserName() async throws -> String?
    func currentUserEmail() async throws -> String?
    func setIdentity(name: String, email: String) async throws
}

public enum GitConfigError: Error, Equatable {
    case binaryNotFound
    case commandFailed(exitCode: Int32, stderr: String)
}

/// Runs `git config --global ...` via the injected ``ProcessRunner``. In tests a
/// sandbox `GIT_CONFIG_GLOBAL` isolates the real git from the environment.
public struct DefaultGitConfigService: GitConfigService {
    private let runner: ProcessRunner
    private let locator: BinaryLocator
    private let gitConfigGlobalPath: String?

    public init(runner: ProcessRunner, locator: BinaryLocator, gitConfigGlobalPath: String?) {
        self.runner = runner
        self.locator = locator
        self.gitConfigGlobalPath = gitConfigGlobalPath
    }

    public func currentUserName() async throws -> String? {
        try await readKey("user.name")
    }

    public func currentUserEmail() async throws -> String? {
        try await readKey("user.email")
    }

    public func setIdentity(name: String, email: String) async throws {
        try await writeKey("user.name", name)
        try await writeKey("user.email", email)
    }

    // MARK: - Private

    private func gitPath() throws -> String {
        guard let path = locator.path(for: "git") else { throw GitConfigError.binaryNotFound }
        return path
    }

    private var environment: [String: String]? {
        // When a sandbox global config is set (tests), also ignore the system
        // config so the result is deterministic regardless of /etc/gitconfig.
        gitConfigGlobalPath.map { ["GIT_CONFIG_GLOBAL": $0, "GIT_CONFIG_NOSYSTEM": "1"] }
    }

    private func readKey(_ key: String) async throws -> String? {
        let output = try await runner.run(try gitPath(), ["config", "--global", key], environment: environment)
        switch output.exitCode {
        case 0:
            let value = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        case 1:
            // git returns 1 when the key is not set.
            return nil
        default:
            throw GitConfigError.commandFailed(exitCode: output.exitCode, stderr: output.stderr)
        }
    }

    private func writeKey(_ key: String, _ value: String) async throws {
        let output = try await runner.run(try gitPath(), ["config", "--global", key, value], environment: environment)
        guard output.exitCode == 0 else {
            throw GitConfigError.commandFailed(exitCode: output.exitCode, stderr: output.stderr)
        }
    }
}
