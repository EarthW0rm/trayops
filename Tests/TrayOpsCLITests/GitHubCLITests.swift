import Testing
import Foundation
import TrayOpsTestSupport

@Suite("github CLI E2E")
struct GitHubCLITests {
    private func sandboxEnvironment(seed: Bool) throws -> (Sandbox, [String: String]) {
        let sandbox = try Sandbox()
        var environment = [
            "HOME": sandbox.home,
            "GIT_CONFIG_GLOBAL": sandbox.gitConfigGlobalPath,
        ]
        if seed {
            let seedURL = sandbox.root.appendingPathComponent("seed.json")
            let json =
                #"{ "accounts": [ { "label": "personal", "gitName": "octocat", "gitEmail": "octo@example.com", "identityFile": "~/.ssh/id_personal" } ] }"#
            try json.write(to: seedURL, atomically: true, encoding: .utf8)
            environment["TRAYOPS_SEED_PATH"] = seedURL.path
        }
        return (sandbox, environment)
    }

    @Test("set then status reports consistent (exit 0)")
    func setThenStatus() throws {
        let (sandbox, environment) = try sandboxEnvironment(seed: true)
        defer { sandbox.destroy() }

        let list = try CLIHarness.run(["github", "list"], extraEnvironment: environment)
        #expect(list.code == 0)
        #expect(list.stdout.contains("personal"))

        let set = try CLIHarness.run(["github", "set", "personal"], extraEnvironment: environment)
        #expect(set.code == 0)

        let status = try CLIHarness.run(["github", "status"], extraEnvironment: environment)
        #expect(status.code == 0)
        #expect(status.stdout.contains("Consistent"))
    }

    @Test("unknown account label fails with a non-zero exit")
    func unknownLabelFails() throws {
        let (sandbox, environment) = try sandboxEnvironment(seed: false)
        defer { sandbox.destroy() }

        let result = try CLIHarness.run(["github", "set", "does-not-exist"], extraEnvironment: environment)
        #expect(result.code != 0)
    }
}
