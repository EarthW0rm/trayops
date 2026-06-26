import Foundation
import TrayOpsCore

/// Builds the real ``AppComposition`` with sandboxed/fake boundaries and an
/// in-memory SwiftData store. Reusing the production factory is what guarantees
/// that passing E2E tests imply a working app. Holds onto the sandbox and fake
/// runner so tests can script responses and inspect side effects.
public final class TestComposition {
    public let sandbox: Sandbox
    public let processRunner: ProcessRunner
    public let binaryLocator: BinaryLocator
    public let environment: SystemEnvironment
    public let composition: AppComposition

    public var mediator: Mediator { composition.mediator }

    /// Defaults to the real ``FoundationProcessRunner`` so git-backed flows run
    /// against real git over the sandbox. Pass a ``FakeProcessRunner`` for
    /// non-deterministic boundaries (e.g. docker/rdctl).
    public init(
        processRunner: ProcessRunner = FoundationProcessRunner(),
        binaryLocator: BinaryLocator? = nil,
        seedURL: URL? = nil,
        gitHubHost: String = "github.com"
    ) throws {
        self.sandbox = try Sandbox()
        self.processRunner = processRunner
        self.binaryLocator = binaryLocator ?? DefaultBinaryLocator(home: sandbox.home)

        let accountsStoreURL = URL(fileURLWithPath: "\(sandbox.home)/accounts.json")

        self.environment = SystemEnvironment(
            processRunner: processRunner,
            binaryLocator: self.binaryLocator,
            homeDirectory: sandbox.home,
            sshConfigPath: sandbox.sshConfigPath,
            gitConfigGlobalPath: sandbox.gitConfigGlobalPath,
            seedURL: seedURL,
            gitHubHost: gitHubHost,
            accountsStoreURL: accountsStoreURL
        )
        self.composition = try AppComposition(environment: environment)
    }
}
