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
}
