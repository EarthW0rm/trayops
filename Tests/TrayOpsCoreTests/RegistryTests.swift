import Testing
import TrayOpsCore

@Suite("FeatureRegistry")
struct RegistryTests {
    @Test("registers feature handlers and lists features")
    func registersAndLists() {
        let feature = FakeFeature()
        let registry = FeatureRegistry(features: [feature])
        let mediator = DefaultMediator()

        registry.registerAll(on: mediator)

        #expect(registry.features.count == 1)
        #expect(feature.registered)
    }

    @Test("appends features via register")
    func appends() {
        let registry = FeatureRegistry()
        registry.register(FakeFeature(id: "a"))
        registry.register(FakeFeature(id: "b"))

        #expect(registry.features.map(\.id) == ["a", "b"])
    }
}
