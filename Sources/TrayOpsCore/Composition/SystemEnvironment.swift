import Foundation

/// The set of system boundaries the platform depends on. App and tests build the
/// same graph swapping only these boundaries — this is what makes
/// "E2E passed ⇒ app works".
public struct SystemEnvironment {
    public let processRunner: ProcessRunner
    public let binaryLocator: BinaryLocator
    /// Absolute path to the user's home directory (sandboxed in tests).
    public let homeDirectory: String
    /// Absolute path to the SSH config file the platform reads/rewrites.
    public let sshConfigPath: String
    /// When set, git invocations use this file as `GIT_CONFIG_GLOBAL` (tests).
    /// `nil` in production means the real global config is used.
    public let gitConfigGlobalPath: String?
    /// Resolved seed file for first-run account seeding, or nil to start empty.
    public let seedURL: URL?
    /// SSH host whose `IdentityFile` is managed.
    public let gitHubHost: String
    /// Location of the JSON account store (sandboxed in tests).
    public let accountsStoreURL: URL

    public init(
        processRunner: ProcessRunner,
        binaryLocator: BinaryLocator,
        homeDirectory: String,
        sshConfigPath: String,
        gitConfigGlobalPath: String? = nil,
        seedURL: URL? = nil,
        gitHubHost: String = "github.com",
        accountsStoreURL: URL
    ) {
        self.processRunner = processRunner
        self.binaryLocator = binaryLocator
        self.homeDirectory = homeDirectory
        self.sshConfigPath = sshConfigPath
        self.gitConfigGlobalPath = gitConfigGlobalPath
        self.seedURL = seedURL
        self.gitHubHost = gitHubHost
        self.accountsStoreURL = accountsStoreURL
    }

    /// Production boundaries: real process runner, real paths, on-disk store.
    /// `HOME` and `GIT_CONFIG_GLOBAL` are read from the environment so the CLI
    /// binary can be sandboxed in E2E tests.
    public static func live() throws -> SystemEnvironment {
        let environment = ProcessInfo.processInfo.environment
        let home = environment["HOME"] ?? NSHomeDirectory()

        let supportDirectory = "\(home)/Library/Application Support/TrayOps"
        try FileManager.default.createDirectory(
            atPath: supportDirectory,
            withIntermediateDirectories: true
        )
        let accountsStoreURL = URL(fileURLWithPath: "\(supportDirectory)/accounts.json")

        return SystemEnvironment(
            processRunner: FoundationProcessRunner(),
            binaryLocator: DefaultBinaryLocator(home: home),
            homeDirectory: home,
            sshConfigPath: "\(home)/.ssh/config",
            gitConfigGlobalPath: environment["GIT_CONFIG_GLOBAL"],
            seedURL: AccountSeed.resolveURL(
                environment: environment,
                home: home,
                currentDirectory: FileManager.default.currentDirectoryPath
            ),
            accountsStoreURL: accountsStoreURL
        )
    }
}
