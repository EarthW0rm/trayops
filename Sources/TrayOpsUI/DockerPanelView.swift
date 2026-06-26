import SwiftUI
import TrayOpsCore

/// Pure presentation of the Docker row: state label + a conditional action button
/// (Start when offline, Shut Down when online) (RN-DK-02).
public struct DockerContentView: View {
    let state: DockerState
    let errorMessage: String?
    let onStart: () -> Void
    let onShutdown: () -> Void

    public init(
        state: DockerState,
        errorMessage: String? = nil,
        onStart: @escaping () -> Void,
        onShutdown: @escaping () -> Void
    ) {
        self.state = state
        self.errorMessage = errorMessage
        self.onStart = onStart
        self.onShutdown = onShutdown
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "shippingbox")
                Text("Docker").font(.headline)
                Spacer()
                Text(state.summary).foregroundStyle(.secondary)
                actionButton
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
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
    @State private var errorMessage: String?

    public init(mediator: Mediator, stateStore: StateStore) {
        self.mediator = mediator
        self.stateStore = stateStore
    }

    public var body: some View {
        let state = (stateStore.snapshot(for: FeatureID.docker) as? DockerState) ?? .unavailable(reason: "unknown")
        // No RefreshAll here: the RootPanelView issues a single coalesced refresh.
        // This panel only reads the StateStore and dispatches actions.
        return DockerContentView(
            state: state,
            errorMessage: errorMessage,
            onStart: { dispatch(DockerStart()) },
            onShutdown: { dispatch(DockerShutdown()) }
        )
    }

    private func dispatch<R: Request>(_ request: R) {
        Task {
            do {
                _ = try await mediator.send(request)
                errorMessage = nil
            } catch {
                errorMessage = "\(error.localizedDescription)"
            }
            _ = try? await mediator.send(RefreshAll())
        }
    }
}
