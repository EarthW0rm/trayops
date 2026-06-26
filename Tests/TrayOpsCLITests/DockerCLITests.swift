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

        let result = try CLIHarness.run(["docker", "status"], extraEnvironment: ["HOME": sandbox.home])

        #expect(result.code == 0)
        let output = result.stdout.lowercased()
        #expect(["online", "offline", "transitioning", "unavailable"].contains { output.contains($0) })
    }
}
