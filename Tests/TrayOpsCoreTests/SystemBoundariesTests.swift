import Testing
import TrayOpsCore
import TrayOpsTestSupport

@Suite("System boundaries")
struct SystemBoundariesTests {
    @Test("FoundationProcessRunner runs git --version and captures stdout")
    func runsGitVersion() async throws {
        let locator = DefaultBinaryLocator()
        guard let git = locator.path(for: "git") else {
            Issue.record("git not found on this machine")
            return
        }
        let runner = FoundationProcessRunner()

        let output = try await runner.run(git, ["--version"])

        #expect(output.exitCode == 0)
        #expect(output.stdout.contains("git version"))
    }

    @Test("BinaryLocator resolves git and returns nil for a missing binary")
    func resolvesGitAndNilForMissing() {
        let locator = DefaultBinaryLocator()

        #expect(locator.path(for: "git") != nil)
        #expect(locator.path(for: "trayops-nonexistent-binary-xyz") == nil)
    }

    @Test("FakeProcessRunner returns the stubbed output")
    func fakeRunnerStubbing() async throws {
        let runner = FakeProcessRunner()
        runner.stub(tool: "docker", args: ["info"], exitCode: 0, stdout: "ok")

        let output = try await runner.run("/usr/bin/docker", ["info"])

        #expect(output.exitCode == 0)
        #expect(output.stdout == "ok")
        #expect(runner.invocations.count == 1)
    }
}
