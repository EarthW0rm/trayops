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

    public init(
        processRunner: ProcessRunner,
        binaryLocator: BinaryLocator,
        homeDirectory: String,
        sshConfigPath: String,
        gitConfigGlobalPath: String? = nil
    ) {
        self.processRunner = processRunner
        self.binaryLocator = binaryLocator
        self.homeDirectory = homeDirectory
        self.sshConfigPath = sshConfigPath
        self.gitConfigGlobalPath = gitConfigGlobalPath
    }

    /// Production boundaries: real process runner, real paths.
    public static func live() -> SystemEnvironment {
        let home = NSHomeDirectory()
        return SystemEnvironment(
            processRunner: FoundationProcessRunner(),
            binaryLocator: DefaultBinaryLocator(home: home),
            homeDirectory: home,
            sshConfigPath: "\(home)/.ssh/config",
            gitConfigGlobalPath: nil
        )
    }
}
