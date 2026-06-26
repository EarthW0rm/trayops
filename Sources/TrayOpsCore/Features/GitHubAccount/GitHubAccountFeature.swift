import Foundation

/// The GitHub Account Function. Conforms to ``Feature`` (+ ``Reconcilable``):
/// `refresh()` resolves the state, `reconcile()` reapplies the target account,
/// and `registerHandlers` wires the use cases (RN-P-01/07, RN-GH-10).
public final class GitHubAccountFeature: Feature, Reconcilable {
    public let id = FeatureID.gitHubAccount
    public let title = "GitHub Account"
    public let systemImage = "person.crop.circle"

    private let store: AccountStore
    private let resolver: AccountStateResolver
    private let applier: AccountApplier
    private let target: AccountTarget

    public init(store: AccountStore, resolver: AccountStateResolver, applier: AccountApplier, target: AccountTarget) {
        self.store = store
        self.resolver = resolver
        self.applier = applier
        self.target = target
    }

    public func registerHandlers(on mediator: Mediator) {
        mediator.register(ResolveGitHubStateHandler(store: store, resolver: resolver))
        mediator.register(ListAccountsHandler(store: store))
        mediator.register(ApplyAccountHandler(store: store, applier: applier, resolver: resolver, target: target))
        mediator.register(ReconcileAccountHandler(store: store, applier: applier, resolver: resolver, target: target))
        mediator.register(AddAccountHandler(store: store))
        mediator.register(UpdateAccountHandler(store: store))
        mediator.register(RemoveAccountHandler(store: store))
    }

    public func commands() -> [FeatureCommand] {
        [FeatureCommand(name: "github", abstract: "Inspect and switch the active GitHub account.")]
    }

    public func refresh() async -> any FeatureState {
        do {
            return try await resolver.resolve(accounts: try store.all())
        } catch {
            return GitHubAccountState.unavailable(reason: "\(error)")
        }
    }

    public func reconcile() async throws {
        guard let id = target.id, let account = try store.all().first(where: { $0.id == id }) else {
            return
        }
        try await applier.apply(account)
    }
}
