import Foundation
import Observation

/// Observable store of per-Feature state snapshots, keyed by `feature.id`.
/// Uses the Observation framework (no SwiftUI) so the GUI can observe it while
/// the core stays UI-agnostic. The GUI reads it on the main actor; the poller
/// publishes updates on the main actor (see `StatePoller`).
@Observable
public final class StateStore {
    public private(set) var snapshots: [String: any FeatureState]

    public init() {
        self.snapshots = [:]
    }

    /// Publishes a snapshot for a Feature. Replaces any previous snapshot.
    public func set(_ id: String, _ state: any FeatureState) {
        snapshots[id] = state
    }

    /// Returns the last published snapshot for a Feature, if any.
    public func snapshot(for id: String) -> (any FeatureState)? {
        snapshots[id]
    }
}
