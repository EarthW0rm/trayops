import Testing
import TrayOpsCore
import TrayOpsTestSupport

@Suite("Composition bootstrap")
struct BootstrapTests {
    @Test("composition builds an empty registry over sandbox boundaries")
    func buildsEmptyRegistry() throws {
        let test = try TestComposition()

        #expect(test.composition.registry.features.isEmpty)
    }

    @Test("StateStore publishes and retrieves a snapshot")
    func stateStorePublishes() throws {
        let store = StateStore()
        store.set("fake", FakeState(label: "hello"))

        let snapshot = store.snapshot(for: "fake") as? FakeState
        #expect(snapshot?.label == "hello")
    }
}
