import Testing
import Foundation
import TrayOpsCore
import TrayOpsTestSupport

@Suite("Logging and process timeout")
struct LoggingTests {
    @Test("the runner logs the command and its exit code")
    func runnerLogsCommandAndExit() async throws {
        let logger = CapturingLogger()
        guard let git = DefaultBinaryLocator().path(for: "git") else {
            Issue.record("git not found")
            return
        }
        let runner = FoundationProcessRunner(logger: logger)

        _ = try await runner.run(git, ["--version"])

        #expect(logger.lines.contains { $0.contains("exit 0") && $0.contains("git") })
    }

    @Test("the runner terminates and logs a timeout")
    func runnerTimesOut() async {
        let logger = CapturingLogger()
        let runner = FoundationProcessRunner(logger: logger, timeout: 0.2)

        await #expect(throws: ProcessRunnerError.self) {
            _ = try await runner.run("/bin/sleep", ["5"])
        }

        #expect(logger.lines.contains { $0.contains("timeout") })
    }

    @Test("FileLogger appends timestamped entries")
    func fileLoggerWrites() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("trayops-log-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: url) }

        let logger = FileLogger(fileURL: url)
        logger.info("hello world")
        logger.error("boom")

        let contents = try String(contentsOf: url, encoding: .utf8)
        #expect(contents.contains("[INFO] hello world"))
        #expect(contents.contains("[ERROR] boom"))
    }
}
