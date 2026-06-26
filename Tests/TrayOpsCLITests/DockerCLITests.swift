import Testing
import Foundation
import TrayOpsTestSupport

@Suite("docker CLI E2E")
struct DockerCLITests {
    /// `docker status` is read-only, so it runs against the real binary. `start`
    /// and `shutdown` are non-deterministic side effects and are covered in-process
    /// with a fake runner (see DockerFlowTests), not here.
    @Test("docker status runs and exits 0 with a known state")
    func statusRuns() throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }

        let process = Process()
        process.executableURL = TestBinary.trayops
        process.arguments = ["docker", "status"]
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = sandbox.home
        process.environment = environment
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0)
        let output = String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).lowercased()
        #expect(["online", "offline", "transitioning", "unavailable"].contains { output.contains($0) })
    }
}
