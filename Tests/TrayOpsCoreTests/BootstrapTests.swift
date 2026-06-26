import Testing
import TrayOpsCore
import TrayOpsTestSupport

@Suite("Composition bootstrap")
struct BootstrapTests {
    @Test("composition registers the GitHub Account Function over sandbox boundaries")
    func registersFeatures() throws {
        let test = try TestComposition()

        #expect(test.composition.registry.features.contains { $0.id == "github-account" })
    }

    @Test("StateStore publishes and retrieves a snapshot")
    func stateStorePublishes() throws {
        let store = StateStore()
        store.set("fake", FakeState(label: "hello"))

        let snapshot = store.snapshot(for: "fake") as? FakeState
        #expect(snapshot?.label == "hello")
    }
}
