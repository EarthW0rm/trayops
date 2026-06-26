import Foundation

/// Isolated filesystem sandbox for tests: a temporary HOME with `.ssh/config`
/// and a dedicated `GIT_CONFIG_GLOBAL` file. Everything lives under a unique
/// temp directory removed on `destroy()`/`deinit`. No process-global mutation,
/// so suites can run in parallel.
public final class Sandbox {
    public let root: URL
    public let home: String
    public let sshConfigPath: String
    public let gitConfigGlobalPath: String

    public init() throws {
        let fileManager = FileManager.default
        root = fileManager.temporaryDirectory
            .appendingPathComponent("trayops-sandbox-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let homeURL = root.appendingPathComponent("home", isDirectory: true)
        try fileManager.createDirectory(at: homeURL, withIntermediateDirectories: true)
        home = homeURL.path

        let sshDir = homeURL.appendingPathComponent(".ssh", isDirectory: true)
        try fileManager.createDirectory(at: sshDir, withIntermediateDirectories: true)
        sshConfigPath = sshDir.appendingPathComponent("config").path

        gitConfigGlobalPath = root.appendingPathComponent("gitconfig").path
    }

    /// Writes content to the sandbox SSH config file.
    public func writeSSHConfig(_ contents: String) throws {
        try contents.write(toFile: sshConfigPath, atomically: true, encoding: .utf8)
    }

    /// Reads the current SSH config file, or nil if it does not exist.
    public func readSSHConfig() -> String? {
        try? String(contentsOfFile: sshConfigPath, encoding: .utf8)
    }

    public func destroy() {
        try? FileManager.default.removeItem(at: root)
    }

    deinit {
        destroy()
    }
}
