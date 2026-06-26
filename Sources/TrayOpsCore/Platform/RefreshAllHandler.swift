import Foundation

/// Refreshes every Function's state, isolating failures: each `refresh()` already
/// returns an "unavailable" state instead of throwing, so one Function cannot
/// stop the others (RN-P-08). Publishes each snapshot to the ``StateStore``.
public struct RefreshAllHandler: RequestHandler {
    let registry: FeatureRegistry
    let stateStore: StateStore

    public init(registry: FeatureRegistry, stateStore: StateStore) {
        self.registry = registry
        self.stateStore = stateStore
    }

    public func handle(_ request: RefreshAll) async throws {
        for feature in registry.features {
            let state = await feature.refresh()
            stateStore.set(feature.id, state)
        }
    }
}
