import Foundation

/// One handler per Request (SRP). After an action, a "transitioning" state is
/// published; the next refresh converges to online/offline (RN-DK-04).

struct ResolveDockerStateHandler: RequestHandler {
    let service: DockerService

    func handle(_ request: ResolveDockerState) async throws -> DockerState {
        await service.status()
    }
}

struct DockerStartHandler: RequestHandler {
    let service: DockerService
    let stateStore: StateStore
    let featureID: String

    func handle(_ request: DockerStart) async throws {
        try await service.start()
        stateStore.set(featureID, DockerState.transitioning)
    }
}

struct DockerShutdownHandler: RequestHandler {
    let service: DockerService
    let stateStore: StateStore
    let featureID: String

    func handle(_ request: DockerShutdown) async throws {
        try await service.shutdown()
        stateStore.set(featureID, DockerState.transitioning)
    }
}
