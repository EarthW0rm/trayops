import TrayOpsCore

/// Process-wide composition for the CLI. Lazily built on first access (thread-safe
/// `static let`), so each subcommand can reach the Mediator without the parser
/// needing to thread dependencies through value-type commands.
enum CLIRuntime {
    static let composition: AppComposition = .live()

    /// The shared Mediator.
    static var mediator: Mediator {
        composition.mediator
    }
}
