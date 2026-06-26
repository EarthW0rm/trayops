import Testing
import Foundation
import TrayOpsTestSupport

@Suite("status / reconcile-all CLI E2E")
struct PlatformCLITests {
    @Test("status prints Function states and reconcile-all reports")
    func statusAndReconcileAll() throws {
        let sandbox = try Sandbox()
        defer { sandbox.destroy() }
        let environment = [
            "HOME": sandbox.home,
            "GIT_CONFIG_GLOBAL": sandbox.gitConfigGlobalPath,
        ]

        let status = try CLIHarness.run(["status"], extraEnvironment: environment)
        #expect(status.code == 0)
        #expect(status.stdout.contains("GitHub Account"))

        let reconcile = try CLIHarness.run(["reconcile-all"], extraEnvironment: environment)
        #expect(reconcile.code == 0)
        #expect(reconcile.stdout.contains("github-account"))
    }
}
