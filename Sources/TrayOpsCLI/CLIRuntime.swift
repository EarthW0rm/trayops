import Foundation
import TrayOpsCore

/// Process-wide composition for the CLI. Lazily built on first access (thread-safe
/// `static let`), so each subcommand can reach the Mediator without the parser
/// needing to thread dependencies through value-type commands. A failure to build
/// the graph (e.g. the SwiftData store cannot open) exits with a clear message.
enum CLIRuntime {
    static let composition: AppComposition = {
        do {
            return try AppComposition.live()
        } catch {
            FileHandle.standardError.write(Data("trayops: failed to initialize: \(error)\n".utf8))
            exit(1)
        }
    }()

    /// The shared Mediator.
    static var mediator: Mediator {
        composition.mediator
    }
}
