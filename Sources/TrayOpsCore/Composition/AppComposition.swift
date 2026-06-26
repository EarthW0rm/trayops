import Foundation

/// Single Composition Root. Builds the object graph (mediator, registry, state
/// store, Functions) from the injected ``SystemEnvironment`` and registers all
/// Feature handlers. The app and the tests use this same factory — only the
/// environment (system boundaries) differs.
///
/// Adding a Function = constructing it here and appending it to the registry.
/// Nothing else in the core or the frontends changes (RN-P-07).
public struct AppComposition {
    public let environment: SystemEnvironment
    public let mediator: Mediator
    public let registry: FeatureRegistry
    public let stateStore: StateStore

    public init(environment: SystemEnvironment) throws {
        self.environment = environment
        let mediator = DefaultMediator()
        let stateStore = StateStore()

        // GitHub Account Function.
        let store = JSONAccountStore(url: environment.accountsStoreURL)
        try store.seedIfEmpty(from: environment.seedURL)
        let git = DefaultGitConfigService(
            runner: environment.processRunner,
            locator: environment.binaryLocator,
            gitConfigGlobalPath: environment.gitConfigGlobalPath
        )
        let ssh = DefaultSSHConfigService(configPath: environment.sshConfigPath)
        let resolver = DefaultAccountStateResolver(git: git, ssh: ssh, host: environment.gitHubHost)
        let applier = DefaultAccountApplier(git: git, ssh: ssh, host: environment.gitHubHost)
        let gitHub = GitHubAccountFeature(
            store: store,
            resolver: resolver,
            applier: applier,
            target: AccountTarget()
        )

        let features: [any Feature] = [gitHub]

        let registry = FeatureRegistry(features: features)
        registry.registerAll(on: mediator)

        self.mediator = mediator
        self.registry = registry
        self.stateStore = stateStore
    }

    /// Convenience factory using production boundaries.
    public static func live() throws -> AppComposition {
        try AppComposition(environment: try .live())
    }
}
