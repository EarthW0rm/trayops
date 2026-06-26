import Foundation

/// Result of running an external process.
public struct ProcessOutput: Sendable, Equatable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

/// Abstraction over running external binaries (git, rdctl, docker). Injected so
/// the domain is testable independent of the real environment.
public protocol ProcessRunner: Sendable {
    /// Runs `executable` with `args`, optionally overriding/extending the child
    /// environment (merged over the current process environment).
    func run(_ executable: String, _ args: [String], environment: [String: String]?) async throws -> ProcessOutput
}

public extension ProcessRunner {
    /// Convenience overload that inherits the current process environment.
    func run(_ executable: String, _ args: [String]) async throws -> ProcessOutput {
        try await run(executable, args, environment: nil)
    }
}

/// `Process`-based runner used in production. Captures stdout/stderr and the exit
/// code; never trusts PATH (callers pass absolute paths via ``BinaryLocator``).
public struct FoundationProcessRunner: ProcessRunner {
    public init() {}

    public func run(_ executable: String, _ args: [String], environment: [String: String]?) async throws -> ProcessOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        if let environment {
            var merged = ProcessInfo.processInfo.environment
            for (key, value) in environment { merged[key] = value }
            process.environment = merged
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return ProcessOutput(
            exitCode: process.terminationStatus,
            stdout: String(decoding: stdoutData, as: UTF8.self),
            stderr: String(decoding: stderrData, as: UTF8.self)
        )
    }
}
