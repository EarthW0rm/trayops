import Foundation
import TrayOpsCore

/// Builds the real ``AppComposition`` with sandboxed/fake boundaries. Reusing the
/// production factory is what guarantees that passing E2E tests imply a working
/// app. Holds onto the sandbox and fake runner so tests can script responses and
/// inspect side effects.
public final class TestComposition {
    public let sandbox: Sandbox
    public let processRunner: FakeProcessRunner
    public let binaryLocator: BinaryLocator
    public let environment: SystemEnvironment
    public let composition: AppComposition

    public init(
        processRunner: FakeProcessRunner = FakeProcessRunner(),
        binaryLocator: BinaryLocator? = nil
    ) throws {
        self.sandbox = try Sandbox()
        self.processRunner = processRunner
        self.binaryLocator = binaryLocator ?? DefaultBinaryLocator(home: sandbox.home)
        self.environment = SystemEnvironment(
            processRunner: processRunner,
            binaryLocator: self.binaryLocator,
            homeDirectory: sandbox.home,
            sshConfigPath: sandbox.sshConfigPath,
            gitConfigGlobalPath: sandbox.gitConfigGlobalPath
        )
        self.composition = AppComposition(environment: environment)
    }
}
