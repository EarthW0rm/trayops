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

        // Drain both pipes concurrently: reading them sequentially could deadlock
        // if the child fills one pipe's buffer while we block on the other.
        async let stdoutData = readToEnd(stdoutPipe.fileHandleForReading)
        async let stderrData = readToEnd(stderrPipe.fileHandleForReading)
        let (out, err) = await (stdoutData, stderrData)
        process.waitUntilExit()

        return ProcessOutput(
            exitCode: process.terminationStatus,
            stdout: String(decoding: out, as: UTF8.self),
            stderr: String(decoding: err, as: UTF8.self)
        )
    }

    private func readToEnd(_ handle: FileHandle) async -> Data {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let data = handle.readDataToEndOfFile()
                continuation.resume(returning: data)
            }
        }
    }
}
