import TrayOpsCore

/// A minimal Feature used across core tests.
final class FakeFeature: Feature {
    let id: String
    let title: String
    let systemImage = "star"
    private(set) var registered = false

    init(id: String = "fake", title: String = "Fake") {
        self.id = id
        self.title = title
    }

    func registerHandlers(on mediator: Mediator) {
        registered = true
    }

    func refresh() async -> any FeatureState {
        FakeState()
    }
}

struct FakeState: FeatureState, Equatable {
    var label: String = "ok"
}
