import Testing
import TrayOpsCore
import TrayOpsTestSupport

@Suite("DockerService")
struct DockerServiceTests {
    private let locator = StubBinaryLocator(["docker": "/bin/docker", "rdctl": "/bin/rdctl"])

    @Test("status is online when docker info exits 0")
    func onlineWhenInfoSucceeds() async {
        let runner = FakeProcessRunner()
        runner.stub(tool: "docker", args: ["info"], exitCode: 0)

        #expect(await DefaultDockerService(runner: runner, locator: locator).status() == .online)
    }

    @Test("status is offline when docker info fails")
    func offlineWhenInfoFails() async {
        let runner = FakeProcessRunner()
        runner.stub(tool: "docker", args: ["info"], exitCode: 1)

        #expect(await DefaultDockerService(runner: runner, locator: locator).status() == .offline)
    }

    @Test("status is unavailable when docker is absent")
    func unavailableWhenAbsent() async {
        let state = await DefaultDockerService(runner: FakeProcessRunner(), locator: StubBinaryLocator([:])).status()

        if case .unavailable = state {
            // expected
        } else {
            Issue.record("expected .unavailable, got \(state)")
        }
    }

    @Test("start and shutdown call rdctl with the correct args")
    func startAndShutdownCallRdctl() async throws {
        let runner = FakeProcessRunner()
        runner.stub(tool: "rdctl", args: ["start"], exitCode: 0)
        runner.stub(tool: "rdctl", args: ["shutdown"], exitCode: 0)
        let service = DefaultDockerService(runner: runner, locator: locator)

        try await service.start()
        try await service.shutdown()

        #expect(runner.invocations.contains { $0.executable.hasSuffix("rdctl") && $0.args == ["start"] })
        #expect(runner.invocations.contains { $0.executable.hasSuffix("rdctl") && $0.args == ["shutdown"] })
    }

    @Test("start throws when rdctl is absent")
    func startThrowsWhenRdctlAbsent() async {
        let service = DefaultDockerService(runner: FakeProcessRunner(), locator: StubBinaryLocator(["docker": "/bin/docker"]))

        await #expect(throws: DockerError.self) {
            try await service.start()
        }
    }

    @Test("start throws when rdctl exits non-zero")
    func startThrowsWhenRdctlFails() async {
        let runner = FakeProcessRunner()
        runner.stub(tool: "rdctl", args: ["start"], exitCode: 1, stderr: "boom")
        let service = DefaultDockerService(runner: runner, locator: locator)

        await #expect(throws: DockerError.self) {
            try await service.start()
        }
    }
}

@Suite("Docker flow")
struct DockerFlowTests {
    @Test("resolve and start through the Mediator")
    func resolveAndStart() async throws {
        let runner = FakeProcessRunner()
        runner.stub(tool: "docker", args: ["info"], exitCode: 0)
        runner.stub(tool: "rdctl", args: ["start"], exitCode: 0)
        let test = try TestComposition(
            processRunner: runner,
            binaryLocator: StubBinaryLocator(["docker": "/bin/docker", "rdctl": "/bin/rdctl"])
        )

        #expect(try await test.mediator.send(ResolveDockerState()) == .online)

        try await test.mediator.send(DockerStart())
        #expect(runner.invocations.contains { $0.executable.hasSuffix("rdctl") && $0.args == ["start"] })
        #expect(test.composition.stateStore.snapshot(for: "docker") as? DockerState == .transitioning)
    }

    @Test("adding Docker did not require a Reconcilable conformance")
    func dockerIsNotReconcilable() throws {
        let test = try TestComposition()
        let docker = test.composition.registry.features.first { $0.id == "docker" }

        #expect(docker != nil)
        #expect(!(docker is Reconcilable))
    }
}
