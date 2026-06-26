import Testing
import Foundation
import TrayOpsTestSupport

@Suite("github CLI E2E")
struct GitHubCLITests {
    private struct Result {
        let code: Int32
        let stdout: String
        let stderr: String
    }

    private func runCLI(_ args: [String], extraEnvironment: [String: String]) throws -> Result {
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
        return Result(
            code: process.terminationStatus,
            stdout: String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            stderr: String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        )
    }

    private func sandboxEnvironment(seed: Bool) throws -> (Sandbox, [String: String]) {
        let sandbox = try Sandbox()
        var environment = [
            "HOME": sandbox.home,
            "GIT_CONFIG_GLOBAL": sandbox.gitConfigGlobalPath,
        ]
        if seed {
            let seedURL = sandbox.root.appendingPathComponent("seed.json")
            let json = #"{ "accounts": [ { "label": "personal", "gitName": "octocat", "gitEmail": "octo@example.com", "identityFile": "~/.ssh/id_personal" } ] }"#
            try json.write(to: seedURL, atomically: true, encoding: .utf8)
            environment["TRAYOPS_SEED_PATH"] = seedURL.path
        }
        return (sandbox, environment)
    }

    @Test("set then status reports consistent (exit 0)")
    func setThenStatus() throws {
        let (sandbox, environment) = try sandboxEnvironment(seed: true)
        defer { sandbox.destroy() }

        let list = try runCLI(["github", "list"], extraEnvironment: environment)
        #expect(list.code == 0)
        #expect(list.stdout.contains("personal"))

        let set = try runCLI(["github", "set", "personal"], extraEnvironment: environment)
        #expect(set.code == 0)

        let status = try runCLI(["github", "status"], extraEnvironment: environment)
        #expect(status.code == 0)
        #expect(status.stdout.contains("Consistent"))
    }

    @Test("unknown account label fails with a non-zero exit")
    func unknownLabelFails() throws {
        let (sandbox, environment) = try sandboxEnvironment(seed: false)
        defer { sandbox.destroy() }

        let result = try runCLI(["github", "set", "does-not-exist"], extraEnvironment: environment)
        #expect(result.code != 0)
    }
}
