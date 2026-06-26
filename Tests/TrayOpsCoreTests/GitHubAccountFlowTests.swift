import Testing
import TrayOpsCore
import TrayOpsTestSupport

/// Behavior E2E of the GitHub Account Function through the real Mediator over a
/// sandbox (real git + real ssh-config rewrites; in-memory account file).
@Suite("GitHub Account flow")
struct GitHubAccountFlowTests {
    @Test("Set makes the state consistent")
    func setMakesConsistent() async throws {
        let test = try TestComposition()
        let account = try await test.mediator.send(
            AddAccount(
                label: "personal", gitName: "octocat", gitEmail: "octo@example.com", identityFile: "~/.ssh/id_personal"
            ))

        let result = try await test.mediator.send(ApplyAccount(id: account.id))
        #expect(result.success)

        let state = try await test.mediator.send(ResolveGitHubState())
        #expect(state == .consistent(account))
    }

    @Test("divergent git/ssh signals are inconsistent")
    func divergentSignalsAreInconsistent() async throws {
        let test = try TestComposition()
        let accountA = try await test.mediator.send(
            AddAccount(
                label: "a", gitName: "name-a", gitEmail: "a@example.com", identityFile: "~/.ssh/id_a"
            ))
        let accountB = try await test.mediator.send(
            AddAccount(
                label: "b", gitName: "name-b", gitEmail: "b@example.com", identityFile: "~/.ssh/id_b"
            ))

        _ = try await test.mediator.send(ApplyAccount(id: accountA.id))

        // Diverge ssh to account B while git stays on A.
        let ssh = DefaultSSHConfigService(configPath: test.sandbox.sshConfigPath)
        try await ssh.activateIdentity(path: "~/.ssh/id_b", host: "github.com")

        let state = try await test.mediator.send(ResolveGitHubState())
        #expect(state == .inconsistent(git: accountA, ssh: accountB))
    }

    @Test("Reconcile realigns to the target account")
    func reconcileRealigns() async throws {
        let test = try TestComposition()
        let accountA = try await test.mediator.send(
            AddAccount(
                label: "a", gitName: "name-a", gitEmail: "a@example.com", identityFile: "~/.ssh/id_a"
            ))
        _ = try await test.mediator.send(
            AddAccount(
                label: "b", gitName: "name-b", gitEmail: "b@example.com", identityFile: "~/.ssh/id_b"
            ))
        _ = try await test.mediator.send(ApplyAccount(id: accountA.id))

        // Break ssh, then reconcile (no id ⇒ last applied target = A).
        let ssh = DefaultSSHConfigService(configPath: test.sandbox.sshConfigPath)
        try await ssh.activateIdentity(path: "~/.ssh/id_b", host: "github.com")

        let result = try await test.mediator.send(ReconcileAccount())
        #expect(result.success)

        let state = try await test.mediator.send(ResolveGitHubState())
        #expect(state == .consistent(accountA))
    }

    @Test("applier does not touch ssh when git fails (RN-GH-09)")
    func applierDoesNotTouchSSHWhenGitFails() async throws {
        let sandbox = try Sandbox()
        try sandbox.writeSSHConfig("Host github.com\n    IdentityFile ~/.ssh/original\n")

        let git = DefaultGitConfigService(
            runner: FoundationProcessRunner(),
            locator: StubBinaryLocator([:]),  // git absent ⇒ setIdentity throws
            gitConfigGlobalPath: sandbox.gitConfigGlobalPath
        )
        let ssh = DefaultSSHConfigService(configPath: sandbox.sshConfigPath)
        let applier = DefaultAccountApplier(git: git, ssh: ssh, host: "github.com")
        let account = Account(label: "x", gitName: "n", gitEmail: "e@example.com", identityFile: "~/.ssh/new")

        await #expect(throws: Error.self) {
            try await applier.apply(account)
        }

        let config = sandbox.readSSHConfig()
        #expect(config?.contains("~/.ssh/original") == true)
        #expect(config?.contains("~/.ssh/new") == false)
    }

    @Test("resolver reports unavailable when git is absent")
    func resolverUnavailableWhenGitAbsent() async throws {
        let sandbox = try Sandbox()
        let git = DefaultGitConfigService(
            runner: FoundationProcessRunner(),
            locator: StubBinaryLocator([:]),
            gitConfigGlobalPath: nil
        )
        let ssh = DefaultSSHConfigService(configPath: sandbox.sshConfigPath)
        let resolver = DefaultAccountStateResolver(git: git, ssh: ssh, host: "github.com")

        let state = try await resolver.resolve(accounts: [])
        if case .unavailable = state {
            // expected
        } else {
            Issue.record("expected .unavailable, got \(state)")
        }
    }

    @Test("UpdateAccount persists the new field values")
    func updateAccountPersists() async throws {
        let test = try TestComposition()
        let created = try await test.mediator.send(
            AddAccount(
                label: "personal", gitName: "octocat", gitEmail: "octo@example.com", identityFile: "~/.ssh/id"
            ))

        let updated = try await test.mediator.send(
            UpdateAccount(
                id: created.id, label: "personal", gitName: "octocat-2", gitEmail: "octo2@example.com",
                identityFile: "~/.ssh/id2"
            ))
        #expect(updated.gitName == "octocat-2")

        let reloaded = try await test.mediator.send(ListAccounts()).first { $0.id == created.id }
        #expect(reloaded?.gitEmail == "octo2@example.com")
        #expect(reloaded?.identityFile == "~/.ssh/id2")
    }

    @Test("CRUD rejects empty fields and removes accounts")
    func crud() async throws {
        let test = try TestComposition()

        await #expect(throws: Error.self) {
            _ = try await test.mediator.send(
                AddAccount(label: "", gitName: "n", gitEmail: "e@e.com", identityFile: "~/.ssh/id"))
        }

        let account = try await test.mediator.send(
            AddAccount(
                label: "temp", gitName: "n", gitEmail: "e@example.com", identityFile: "~/.ssh/id"
            ))
        #expect(try await test.mediator.send(ListAccounts()).contains { $0.id == account.id })

        try await test.mediator.send(RemoveAccount(id: account.id))
        #expect(try await test.mediator.send(ListAccounts()).isEmpty)
    }
}
