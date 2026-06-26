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

public enum ProcessRunnerError: Error, Equatable {
    /// The process did not finish within the configured timeout and was terminated.
    case timedOut(executable: String, seconds: TimeInterval)
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
/// Every invocation is logged (command, exit code, duration, timeouts and spawn
/// failures) and bounded by a timeout so a hung tool cannot stall the platform.
public struct FoundationProcessRunner: ProcessRunner {
    private let logger: Logger
    private let timeout: TimeInterval

    public init(logger: Logger = NullLogger(), timeout: TimeInterval = 30) {
        self.logger = logger
        self.timeout = timeout
    }

    public func run(_ executable: String, _ args: [String], environment: [String: String]?) async throws -> ProcessOutput {
        let command = ([executable] + args).joined(separator: " ")

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

        let started = Date()
        do {
            try process.run()
        } catch {
            logger.error("spawn failed: \(command): \(error)")
            throw error
        }
        logger.debug("exec: \(command)")

        // Drain both pipes concurrently: reading them sequentially could deadlock
        // if the child fills one pipe's buffer while we block on the other.
        async let stdoutData = readToEnd(stdoutPipe.fileHandleForReading)
        async let stderrData = readToEnd(stderrPipe.fileHandleForReading)

        if await timedOut(process, deadline: started.addingTimeInterval(timeout)) {
            process.terminate()
            _ = await (stdoutData, stderrData)
            logger.error("timeout after \(Int(timeout))s: \(command)")
            throw ProcessRunnerError.timedOut(executable: executable, seconds: timeout)
        }

        let (out, err) = await (stdoutData, stderrData)
        let elapsedMillis = Int(Date().timeIntervalSince(started) * 1000)
        let exitCode = process.terminationStatus
        logger.log(exitCode == 0 ? .info : .warning, "exit \(exitCode) in \(elapsedMillis)ms: \(command)")

        return ProcessOutput(
            exitCode: exitCode,
            stdout: String(decoding: out, as: UTF8.self),
            stderr: String(decoding: err, as: UTF8.self)
        )
    }

    /// Polls until the process exits or the deadline passes. Returns true on timeout.
    private func timedOut(_ process: Process, deadline: Date) async -> Bool {
        while process.isRunning {
            if Date() >= deadline { return true }
            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
        }
        return false
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
