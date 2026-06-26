import Testing
import TrayOpsCore
import TrayOpsTestSupport

@Suite("GitConfigService")
struct GitConfigServiceTests {
    @Test("sets and reads the identity in an isolated git config")
    func setsAndReadsIdentity() async throws {
        let sandbox = try Sandbox()
        let service = DefaultGitConfigService(
            runner: FoundationProcessRunner(),
            locator: DefaultBinaryLocator(),
            gitConfigGlobalPath: sandbox.gitConfigGlobalPath
        )

        try await service.setIdentity(name: "octocat", email: "octo@example.com")

        #expect(try await service.currentUserName() == "octocat")
        #expect(try await service.currentUserEmail() == "octo@example.com")
    }

    @Test("returns nil when the identity is unset")
    func nilWhenUnset() async throws {
        let sandbox = try Sandbox()
        let service = DefaultGitConfigService(
            runner: FoundationProcessRunner(),
            locator: DefaultBinaryLocator(),
            gitConfigGlobalPath: sandbox.gitConfigGlobalPath
        )

        #expect(try await service.currentUserName() == nil)
    }

    @Test("throws a typed error when git is absent")
    func throwsWhenGitAbsent() async {
        let service = DefaultGitConfigService(
            runner: FoundationProcessRunner(),
            locator: StubBinaryLocator([:]),
            gitConfigGlobalPath: nil
        )

        await #expect(throws: GitConfigError.self) {
            _ = try await service.currentUserName()
        }
    }

    @Test("restores the previous user.name when the email write fails (RN-GH-09)")
    func restoresUserNameWhenEmailWriteFails() async throws {
        let runner = FakeProcessRunner()
        // Insertion order matters: read of the previous name first, then writes.
        runner.stub(tool: "git", args: ["config", "--global", "user.name"], exitCode: 0, stdout: "previous-octocat\n")
        runner.stub(tool: "git", args: ["config", "--global", "user.name", "octocat"], exitCode: 0)
        // The email write fails, which must trigger the rollback.
        runner.stub(tool: "git", args: ["config", "--global", "user.email", "octo@example.com"], exitCode: 1, stderr: "boom")
        // Rollback restores the previously snapshotted name.
        runner.stub(tool: "git", args: ["config", "--global", "user.name", "previous-octocat"], exitCode: 0)

        let service = DefaultGitConfigService(
            runner: runner,
            locator: StubBinaryLocator(["git": "/usr/bin/git"]),
            gitConfigGlobalPath: nil
        )

        await #expect(throws: GitConfigError.self) {
            try await service.setIdentity(name: "octocat", email: "octo@example.com")
        }

        // The last write must restore user.name to its prior value.
        let restored = FakeProcessRunner.Invocation(
            executable: "/usr/bin/git",
            args: ["config", "--global", "user.name", "previous-octocat"]
        )
        #expect(runner.invocations.contains(restored))
        #expect(runner.invocations.last == restored)
    }

    @Test("unsets user.name on rollback when there was no previous value")
    func unsetsUserNameWhenNoPreviousValue() async throws {
        let runner = FakeProcessRunner()
        // No previous name: git exits 1 with empty stderr (unset).
        runner.stub(tool: "git", args: ["config", "--global", "user.name"], exitCode: 1)
        runner.stub(tool: "git", args: ["config", "--global", "user.name", "octocat"], exitCode: 0)
        runner.stub(tool: "git", args: ["config", "--global", "user.email", "octo@example.com"], exitCode: 1, stderr: "boom")
        runner.stub(tool: "git", args: ["config", "--global", "--unset", "user.name"], exitCode: 0)

        let service = DefaultGitConfigService(
            runner: runner,
            locator: StubBinaryLocator(["git": "/usr/bin/git"]),
            gitConfigGlobalPath: nil
        )

        await #expect(throws: GitConfigError.self) {
            try await service.setIdentity(name: "octocat", email: "octo@example.com")
        }

        let unset = FakeProcessRunner.Invocation(
            executable: "/usr/bin/git",
            args: ["config", "--global", "--unset", "user.name"]
        )
        #expect(runner.invocations.last == unset)
    }

    @Test("treats exit 1 with non-empty stderr as a real error, not unset")
    func exitOneWithStderrIsAnError() async {
        let runner = FakeProcessRunner()
        runner.stub(tool: "git", args: ["config", "--global", "user.name"], exitCode: 1, stderr: "fatal: bad config")

        let service = DefaultGitConfigService(
            runner: runner,
            locator: StubBinaryLocator(["git": "/usr/bin/git"]),
            gitConfigGlobalPath: nil
        )

        await #expect(throws: GitConfigError.self) {
            _ = try await service.currentUserName()
        }
    }

    @Test("treats exit 1 with empty stderr as unset")
    func exitOneWithoutStderrIsUnset() async throws {
        let runner = FakeProcessRunner()
        runner.stub(tool: "git", args: ["config", "--global", "user.name"], exitCode: 1)

        let service = DefaultGitConfigService(
            runner: runner,
            locator: StubBinaryLocator(["git": "/usr/bin/git"]),
            gitConfigGlobalPath: nil
        )

        #expect(try await service.currentUserName() == nil)
    }
}
