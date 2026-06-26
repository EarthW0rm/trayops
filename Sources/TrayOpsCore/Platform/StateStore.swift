import Foundation
import Observation

/// Observable store of per-Feature state snapshots, keyed by `feature.id`.
/// Uses the Observation framework (no SwiftUI) so the GUI can observe it while
/// the core stays UI-agnostic.
///
/// All dictionary access is serialized by an internal lock, so the 15s poller
/// (which publishes from a background task) and the GUI (which reads on the main
/// actor) cannot mutate/read the storage concurrently. The Observation registrar
/// is itself thread-safe, so observation continues to work across threads.
@Observable
public final class StateStore {
    @ObservationIgnored private let lock = NSLock()
    public private(set) var snapshots: [String: any FeatureState]

    public init() {
        self.snapshots = [:]
    }

    /// Publishes a snapshot for a Feature. Replaces any previous snapshot.
    public func set(_ id: String, _ state: any FeatureState) {
        lock.lock()
        defer { lock.unlock() }
        snapshots[id] = state
    }

    /// Returns the last published snapshot for a Feature, if any.
    public func snapshot(for id: String) -> (any FeatureState)? {
        lock.lock()
        defer { lock.unlock() }
        return snapshots[id]
    }
}
