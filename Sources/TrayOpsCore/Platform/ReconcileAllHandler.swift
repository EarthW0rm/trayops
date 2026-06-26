import Foundation

/// Reconciles every ``Reconcilable`` Function and refreshes all of them. A failure
/// in one Function is captured and does not interrupt the others (RN-P-03/08).
/// Non-reconcilable Functions are only refreshed and excluded from the report.
public struct ReconcileAllHandler: RequestHandler {
    let registry: FeatureRegistry
    let stateStore: StateStore

    public init(registry: FeatureRegistry, stateStore: StateStore) {
        self.registry = registry
        self.stateStore = stateStore
    }

    public func handle(_ request: ReconcileAll) async throws -> ReconcileReportDTO {
        var entries: [ReconcileReportDTO.Entry] = []

        for feature in registry.features {
            guard let reconcilable = feature as? Reconcilable else {
                stateStore.set(feature.id, await feature.refresh())
                continue
            }

            do {
                try await reconcilable.reconcile()
                entries.append(.init(featureID: feature.id, success: true, message: nil))
            } catch {
                entries.append(.init(featureID: feature.id, success: false, message: "\(error)"))
            }
            stateStore.set(feature.id, await feature.refresh())
        }

        return ReconcileReportDTO(entries: entries)
    }
}
