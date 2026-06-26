import SwiftUI
import TrayOpsCore

/// Pure, IO-free presentation of the GitHub Account row. Rendering is a function
/// of the inputs only, which keeps it trivially inspectable in UI tests.
public struct GitHubAccountContentView: View {
    let state: GitHubAccountState
    let accounts: [AccountDTO]
    @Binding var selectedID: UUID?
    let onSet: () -> Void
    let onReconcile: () -> Void

    public init(
        state: GitHubAccountState,
        accounts: [AccountDTO],
        selectedID: Binding<UUID?>,
        onSet: @escaping () -> Void,
        onReconcile: @escaping () -> Void
    ) {
        self.state = state
        self.accounts = accounts
        self._selectedID = selectedID
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
        }
    }
}

/// Container that wires the presentation to the Mediator (no business logic).
public struct GitHubAccountPanelView: View {
    private let mediator: Mediator
    @State private var accounts: [AccountDTO] = []
    @State private var state: GitHubAccountState = .unknown
    @State private var selectedID: UUID?

    public init(mediator: Mediator) {
        self.mediator = mediator
    }

    private enum ActionKind { case apply, reconcile }

    public var body: some View {
        GitHubAccountContentView(
            state: state,
            accounts: accounts,
            selectedID: $selectedID,
            onSet: { dispatch(.apply) },
            onReconcile: { dispatch(.reconcile) }
        )
        .task { await reload() }
    }

    private func reload() async {
        accounts = (try? await mediator.send(ListAccounts())) ?? []
        state = (try? await mediator.send(ResolveGitHubState())) ?? .unknown
        if selectedID == nil { selectedID = accounts.first?.id }
    }

    private func dispatch(_ kind: ActionKind) {
        guard let id = selectedID else { return }
        Task {
            switch kind {
            case .apply: _ = try? await mediator.send(ApplyAccount(id: id))
            case .reconcile: _ = try? await mediator.send(ReconcileAccount(id: id))
            }
            await reload()
        }
    }
}
