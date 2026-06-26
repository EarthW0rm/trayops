import Testing
import Foundation
import TrayOpsCore
import TrayOpsTestSupport

// MARK: - Spies

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() { lock.lock(); count += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}

private struct SpyState: FeatureState, Equatable {
    let value: String
}

private final class SpyFeature: Feature {
    let id: String
    let title = "Spy"
    let systemImage = "star"
    let stateValue: String
    let refreshes = Counter()

    init(id: String, stateValue: String = "ok") {
        self.id = id
        self.stateValue = stateValue
    }

    func registerHandlers(on mediator: Mediator) {}
    func commands() -> [FeatureCommand] { [] }
    func refresh() async -> any FeatureState {
        refreshes.increment()
        return SpyState(value: stateValue)
    }
}

private final class ReconcilableSpy: Feature, Reconcilable {
    let id: String
    let title = "Reconcilable Spy"
    let systemImage = "arrow.triangle.2.circlepath"
    let shouldFail: Bool
    let reconciles = Counter()

    init(id: String, shouldFail: Bool) {
        self.id = id
        self.shouldFail = shouldFail
    }

    struct ReconcileFailure: Error {}

    func registerHandlers(on mediator: Mediator) {}
    func commands() -> [FeatureCommand] { [] }
    func refresh() async -> any FeatureState { SpyState(value: "refreshed") }
    func reconcile() async throws {
        reconciles.increment()
        if shouldFail { throw ReconcileFailure() }
    }
}

// MARK: - Tests

@Suite("Platform state and reconcile")
struct PlatformFlowTests {
    @Test("RefreshAll publishes every Function's state")
    func refreshAllPublishesAll() async throws {
        let registry = FeatureRegistry(features: [SpyFeature(id: "a", stateValue: "a"), SpyFeature(id: "b", stateValue: "b")])
        let store = StateStore()
        let mediator = DefaultMediator()
        mediator.register(RefreshAllHandler(registry: registry, stateStore: store))

        try await mediator.send(RefreshAll())

        #expect((store.snapshot(for: "a") as? SpyState)?.value == "a")
        #expect((store.snapshot(for: "b") as? SpyState)?.value == "b")
    }

    @Test("StatePoller fires repeated refreshes at a short interval")
    func pollerFiresRepeatedly() async throws {
        let spy = SpyFeature(id: "a")
        let registry = FeatureRegistry(features: [spy])
        let store = StateStore()
        let mediator = DefaultMediator()
        mediator.register(RefreshAllHandler(registry: registry, stateStore: store))

        let poller = StatePoller(intervalSeconds: 0.01, mediator: mediator)
        poller.start()
        try await Task.sleep(nanoseconds: 80_000_000)
        poller.stop()

        #expect(spy.refreshes.value >= 2)
    }

    @Test("ReconcileAll reconciles reconcilable Functions and reports per Function")
    func reconcileAllReports() async throws {
        let reconcilable = ReconcilableSpy(id: "recon", shouldFail: false)
        let failing = ReconcilableSpy(id: "failing", shouldFail: true)
        let plain = SpyFeature(id: "plain")
        let registry = FeatureRegistry(features: [reconcilable, failing, plain])
        let store = StateStore()
        let mediator = DefaultMediator()
        mediator.register(ReconcileAllHandler(registry: registry, stateStore: store))

        let report = try await mediator.send(ReconcileAll())

        // Only reconcilable Functions appear in the report.
        #expect(report.entries.count == 2)
        #expect(report.entries.contains { $0.featureID == "recon" && $0.success })
        #expect(report.entries.contains { $0.featureID == "failing" && !$0.success })
        // A failure does not stop the others.
        #expect(reconcilable.reconciles.value == 1)
        #expect(failing.reconciles.value == 1)
        // Every Function is refreshed, including the non-reconcilable one.
        #expect(store.snapshot(for: "plain") != nil)
    }

    @Test("RefreshAll isolates a failing Function — others still update (RN-P-08)")
    func refreshAllIsolatesFailure() async throws {
        let runner = FakeProcessRunner()
        runner.stub(tool: "docker", args: ["info"], exitCode: 0)
        // git absent ⇒ GitHub refresh resolves to .unavailable; docker stays online.
        let test = try TestComposition(
            processRunner: runner,
            binaryLocator: StubBinaryLocator(["docker": "/bin/docker"])
        )

        try await test.mediator.send(RefreshAll())

        #expect(test.composition.stateStore.snapshot(for: FeatureID.docker) as? DockerState == .online)
        let gitHub = test.composition.stateStore.snapshot(for: FeatureID.gitHubAccount) as? GitHubAccountState
        if case .unavailable = gitHub {
            // expected — its failure did not stop Docker from publishing.
        } else {
            Issue.record("expected GitHub .unavailable, got \(String(describing: gitHub))")
        }
    }

    @Test("ReconcileAll reconciles the real GitHub Function")
    func reconcileAllOverComposition() async throws {
        let test = try TestComposition()
        let account = try await test.mediator.send(AddAccount(
            label: "personal", gitName: "octocat", gitEmail: "octo@example.com", identityFile: "~/.ssh/id_personal"
        ))
        _ = try await test.mediator.send(ApplyAccount(id: account.id))

        let report = try await test.mediator.send(ReconcileAll())

        #expect(report.entries.contains { $0.featureID == "github-account" && $0.success })
    }
}
