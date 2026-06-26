import SwiftUI
import AppKit
import TrayOpsCore

/// Root panel shown in the menu bar window. Renders one row per registered
/// Function (none yet in the platform foundation) and observes the `StateStore`.
/// Contains no business logic — it only reads state and dispatches requests.
public struct RootPanelView: View {
    private let composition: AppComposition

    public init(composition: AppComposition) {
        self.composition = composition
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TrayOps")
                .font(.headline)

            if composition.registry.features.isEmpty {
                Text("No functions registered")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(composition.registry.features, id: \.id) { feature in
                    featureView(for: feature)
                    Divider()
                }
                Button("Reconcile All") {
                    Task { _ = try? await composition.mediator.send(ReconcileAll()) }
                }
            }

            Button("Quit TrayOps") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 300)
    }

    /// Resolves the view for a Feature. Adding a Feature adds a case here (a GUI
    /// concern); the core, Mediator and poller are untouched (RN-P-07).
    @ViewBuilder
    private func featureView(for feature: any Feature) -> some View {
        switch feature.id {
        case "github-account":
            GitHubAccountPanelView(mediator: composition.mediator, stateStore: composition.stateStore)
        case "docker":
            DockerPanelView(mediator: composition.mediator, stateStore: composition.stateStore)
        default:
            HStack {
                Image(systemName: feature.systemImage)
                Text(feature.title)
            }
        }
    }
}
