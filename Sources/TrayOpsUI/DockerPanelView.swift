import SwiftUI
import TrayOpsCore

/// Pure presentation of the Docker row: state label + a conditional action button
/// (Start when offline, Shut Down when online) (RN-DK-02).
public struct DockerContentView: View {
    let state: DockerState
    let onStart: () -> Void
    let onShutdown: () -> Void

    public init(state: DockerState, onStart: @escaping () -> Void, onShutdown: @escaping () -> Void) {
        self.state = state
        self.onStart = onStart
        self.onShutdown = onShutdown
    }

    public var body: some View {
        HStack {
            Image(systemName: "shippingbox")
            Text("Docker").font(.headline)
            Spacer()
            Text(state.summary).foregroundStyle(.secondary)
            actionButton
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch state {
        case .online:
            Button("Shut Down", action: onShutdown)
        case .offline:
            Button("Start", action: onStart)
        case .transitioning, .unavailable:
            EmptyView()
        }
    }
}

/// Container wiring the Docker presentation to the Mediator (no business logic);
/// state comes from the observed ``StateStore``.
public struct DockerPanelView: View {
    private let mediator: Mediator
    private let stateStore: StateStore

    public init(mediator: Mediator, stateStore: StateStore) {
        self.mediator = mediator
        self.stateStore = stateStore
    }

    public var body: some View {
        let state = (stateStore.snapshot(for: "docker") as? DockerState) ?? .unavailable(reason: "unknown")
        return DockerContentView(
            state: state,
            onStart: { dispatch(DockerStart()) },
            onShutdown: { dispatch(DockerShutdown()) }
        )
        .task { _ = try? await mediator.send(RefreshAll()) }
    }

    private func dispatch<R: Request>(_ request: R) {
        Task {
            _ = try? await mediator.send(request)
            _ = try? await mediator.send(RefreshAll())
        }
    }
}
