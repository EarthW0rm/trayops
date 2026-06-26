import Testing
import Foundation
import TrayOpsTestSupport

@Suite("status / reconcile-all CLI E2E")
struct PlatformCLITests {
    private struct Result {
        let code: Int32
        let stdout: String
    }

    private func runCLI(_ args: [String], extraEnvironment: [String: String]) throws -> Result {
        let process = Process()
        process.executableURL = TestBinary.trayops
        process.arguments = args
        var environment = ProcessInfo.processInfo.environment
        for (key, value) in extraEnvironment { environment[key] = value }
        process.environment = environment

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()
        return Result(
            code: process.terminationStatus,
            stdout: String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        )
    }

    @Test("status prints Function states and reconcile-all reports")
    func statusAndReconcileAll() throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }
        let environment = [
            "HOME": sandbox.home,
            "GIT_CONFIG_GLOBAL": sandbox.gitConfigGlobalPath,
        ]

        let status = try runCLI(["status"], extraEnvironment: environment)
        #expect(status.code == 0)
        #expect(status.stdout.contains("GitHub Account"))

        let reconcile = try runCLI(["reconcile-all"], extraEnvironment: environment)
        #expect(reconcile.code == 0)
        #expect(reconcile.stdout.contains("github-account"))
    }
}
