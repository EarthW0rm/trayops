import Foundation

/// Result of running the `trayops` CLI binary in a test.
public struct CLIResult {
    public let code: Int32
    public let stdout: String
    public let stderr: String
}

/// Runs the real `trayops` binary for CLI E2E tests, merging the given overrides
/// onto the current environment (e.g. a sandboxed HOME / GIT_CONFIG_GLOBAL).
public enum CLIHarness {
    public static func run(_ args: [String], extraEnvironment: [String: String] = [:]) throws -> CLIResult {
        let process = Process()
        process.executableURL = TestBinary.trayops
        process.arguments = args
        var environment = ProcessInfo.processInfo.environment
        for (key, value) in extraEnvironment { environment[key] = value }
        process.environment = environment

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()
        return CLIResult(
            code: process.terminationStatus,
            stdout: String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            stderr: String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        )
    }
}
