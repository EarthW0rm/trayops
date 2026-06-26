import SwiftUI
import TrayOpsCore

/// Pure, IO-free presentation of the GitHub Account row. Rendering is a function
/// of the inputs only, which keeps it trivially inspectable in UI tests.
public struct GitHubAccountContentView: View {
    let state: GitHubAccountState
    let accounts: [AccountDTO]
    @Binding var selectedID: UUID?
    let errorMessage: String?
    let onSet: () -> Void
    let onReconcile: () -> Void

    public init(
        state: GitHubAccountState,
        accounts: [AccountDTO],
        selectedID: Binding<UUID?>,
        errorMessage: String? = nil,
        onSet: @escaping () -> Void,
        onReconcile: @escaping () -> Void
    ) {
        self.state = state
        self.accounts = accounts
        self._selectedID = selectedID
        self.errorMessage = errorMessage
        self.onSet = onSet
        self.onReconcile = onReconcile
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "person.crop.circle")
                Text("GitHub Account").font(.headline)
            }
            Text(state.summary)
                .foregroundStyle(.secondary)

            Picker("Account", selection: $selectedID) {
                ForEach(accounts) { account in
                    Text(account.label).tag(Optional(account.id))
                }
            }
            .labelsHidden()

            HStack {
                Button("Set", action: onSet)
                Button("Reconcile", action: onReconcile)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

/// Container that wires the presentation to the Mediator (no business logic). The
/// displayed state comes from the observed ``StateStore`` (RN-P-01); actions
/// trigger a `RefreshAll` so the snapshot updates.
public struct GitHubAccountPanelView: View {
    private let mediator: Mediator
    private let stateStore: StateStore
    @State private var accounts: [AccountDTO] = []
    @State private var selectedID: UUID?
    @State private var errorMessage: String?

    public init(mediator: Mediator, stateStore: StateStore) {
        self.mediator = mediator
        self.stateStore = stateStore
    }

    private enum ActionKind { case apply, reconcile }

    public var body: some View {
        let state = (stateStore.snapshot(for: FeatureID.gitHubAccount) as? GitHubAccountState) ?? .unknown
        return GitHubAccountContentView(
            state: state,
            accounts: accounts,
            selectedID: $selectedID,
            errorMessage: errorMessage,
            onSet: { dispatch(.apply) },
            onReconcile: { dispatch(.reconcile) }
        )
        .task { await initialLoad() }
    }

    private func initialLoad() async {
        // Only load the account list here; the RootPanelView issues a single
        // coalesced RefreshAll, so this panel just reads the StateStore for state.
        // A ListAccounts failure surfaces as an error message instead of an
        // indistinguishable empty picker.
        do {
            accounts = try await mediator.send(ListAccounts())
            if selectedID == nil { selectedID = accounts.first?.id }
        } catch {
            errorMessage = "\(error.localizedDescription)"
        }
    }

    private func dispatch(_ kind: ActionKind) {
        guard let id = selectedID else { return }
        Task {
            do {
                let result: ApplyResultDTO
                switch kind {
                case .apply: result = try await mediator.send(ApplyAccount(id: id))
                case .reconcile: result = try await mediator.send(ReconcileAccount(id: id))
                }
                errorMessage = result.success ? nil : (result.message ?? "Operation failed")
            } catch {
                errorMessage = "\(error)"
            }
            _ = try? await mediator.send(RefreshAll())
        }
    }
}
