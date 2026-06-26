import ArgumentParser

/// CLI root and process entry point. Subcommands are added by subsequent User
/// Stories (github, status, reconcile-all, docker). With no arguments it prints
/// help; `--help` exits 0.
@main
struct TrayopsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "trayops",
        abstract: "Personal macOS tray operations platform — CLI frontend.",
        subcommands: [GitHubCommand.self, StatusCommand.self, ReconcileAllCommand.self]
    )
}
