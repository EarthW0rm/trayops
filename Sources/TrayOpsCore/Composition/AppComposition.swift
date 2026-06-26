import Foundation

/// Single Composition Root. Builds the object graph (mediator, registry, state
/// store) from the injected ``SystemEnvironment`` and registers all Feature
/// handlers. The app and the tests use this same factory — only the environment
/// (system boundaries) differs.
///
/// Adding a Function = constructing it here and appending it to the registry.
/// Nothing else in the core or the frontends changes (RN-P-07).
public struct AppComposition {
    public let environment: SystemEnvironment
    public let mediator: Mediator
    public let registry: FeatureRegistry
    public let stateStore: StateStore

    public init(environment: SystemEnvironment) {
        self.environment = environment
        let mediator = DefaultMediator()
        let stateStore = StateStore()

        // No Functions yet — registered in subsequent User Stories.
        let features: [any Feature] = []

        let registry = FeatureRegistry(features: features)
        registry.registerAll(on: mediator)

        self.mediator = mediator
        self.registry = registry
        self.stateStore = stateStore
    }

    /// Convenience factory using production boundaries.
    public static func live() -> AppComposition {
        AppComposition(environment: .live())
    }
}
