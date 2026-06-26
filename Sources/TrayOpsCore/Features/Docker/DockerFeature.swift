import Foundation

/// The Docker Control Function. A plain ``Feature`` (no ``Reconcilable`` — Docker
/// has no persisted desired state). Adding it required only registering it in the
/// Composition Root (RN-P-07).
public final class DockerFeature: Feature {
    public let id = FeatureID.docker
    public let title = "Docker"
    public let systemImage = "shippingbox"

    private let service: DockerService
    private let stateStore: StateStore

    public init(service: DockerService, stateStore: StateStore) {
        self.service = service
        self.stateStore = stateStore
    }

    public func registerHandlers(on mediator: Mediator) {
        mediator.register(ResolveDockerStateHandler(service: service))
        mediator.register(DockerStartHandler(service: service, stateStore: stateStore, featureID: id))
        mediator.register(DockerShutdownHandler(service: service, stateStore: stateStore, featureID: id))
    }

    public func refresh() async -> any FeatureState {
        await service.status()
    }
}
