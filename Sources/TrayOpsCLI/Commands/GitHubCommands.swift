import Foundation
import ArgumentParser
import TrayOpsCore

/// `trayops github ...` — full parity with the GUI GitHub Account Function. Each
/// subcommand dispatches the equivalent Request through the Mediator (RN-P-05)
/// and maps the result to stdout + an exit code (RN-P-06).
struct GitHubCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "github",
        abstract: "Inspect and switch the active GitHub account.",
        subcommands: [Status.self, ListAccountsCommand.self, Set.self, Reconcile.self, AccountCommand.self]
    )
}

extension GitHubCommand {
    struct Status: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status", abstract: "Show the active account state.")
        func run() async throws {
            let state = try await CLIRuntime.mediator.send(ResolveGitHubState())
            print(state.summary)
        }
    }

    struct ListAccountsCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "list", abstract: "List the registered accounts.")
        func run() async throws {
            let accounts = try await CLIRuntime.mediator.send(ListAccounts())
            if accounts.isEmpty {
                print("No accounts registered.")
                return
            }
            for account in accounts {
                print("\(account.label)\t\(account.gitName)\t\(account.gitEmail)\t\(account.identityFile)")
            }
        }
    }

    struct Set: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "set", abstract: "Apply (Set) an account by label.")
        @Argument(help: "Account label.") var label: String

        func run() async throws {
            let account = try await CLIErrors.account(labeled: label)
            let result = try await CLIRuntime.mediator.send(ApplyAccount(id: account.id))
            print(result.state.summary)
            try CLIErrors.requireSuccess(result)
        }
    }

    struct Reconcile: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "reconcile", abstract: "Reconcile an account (defaults to the last applied).")
        @Argument(help: "Account label (optional).") var label: String?

        func run() async throws {
            var id: UUID?
            if let label {
                id = try await CLIErrors.account(labeled: label).id
            }
            let result = try await CLIRuntime.mediator.send(ReconcileAccount(id: id))
            print(result.state.summary)
            try CLIErrors.requireSuccess(result)
        }
    }

    struct AccountCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "account",
            abstract: "Manage the account list.",
            subcommands: [Add.self, Edit.self, Remove.self]
        )

        struct Add: AsyncParsableCommand {
            static let configuration = CommandConfiguration(commandName: "add", abstract: "Add a new account.")
            @Option(help: "Label.") var label: String
            @Option(name: .customLong("git-name"), help: "git user.name.") var gitName: String
            @Option(name: .customLong("git-email"), help: "git user.email.") var gitEmail: String
            @Option(name: .customLong("identity-file"), help: "SSH IdentityFile path.") var identityFile: String

            func run() async throws {
                let dto = try await CLIRuntime.mediator.send(
                    AddAccount(
                        label: label, gitName: gitName, gitEmail: gitEmail, identityFile: identityFile
                    ))
                print("Added account: \(dto.label)")
            }
        }

        struct Edit: AsyncParsableCommand {
            static let configuration = CommandConfiguration(commandName: "edit", abstract: "Edit an existing account.")
            @Argument(help: "Label of the account to edit.") var label: String
            @Option(name: .customLong("git-name"), help: "git user.name.") var gitName: String
            @Option(name: .customLong("git-email"), help: "git user.email.") var gitEmail: String
            @Option(name: .customLong("identity-file"), help: "SSH IdentityFile path.") var identityFile: String

            func run() async throws {
                let account = try await CLIErrors.account(labeled: label)
                let dto = try await CLIRuntime.mediator.send(
                    UpdateAccount(
                        id: account.id, label: label, gitName: gitName, gitEmail: gitEmail, identityFile: identityFile
                    ))
                print("Updated account: \(dto.label)")
            }
        }

        struct Remove: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                commandName: "remove", abstract: "Remove an account by label.")
            @Argument(help: "Label of the account to remove.") var label: String

            func run() async throws {
                let account = try await CLIErrors.account(labeled: label)
                try await CLIRuntime.mediator.send(RemoveAccount(id: account.id))
                print("Removed account: \(label)")
            }
        }
    }
}

/// CLI error helpers shared by the github subcommands.
enum CLIErrors {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    /// Resolves an account by label or throws (non-zero exit).
    static func account(labeled label: String) async throws -> AccountDTO {
        let accounts = try await CLIRuntime.mediator.send(ListAccounts())
        guard let account = accounts.first(where: { $0.label == label }) else {
            throw Failure(description: "Unknown account label: \(label)")
        }
        return account
    }

    /// Maps an apply/reconcile failure to a non-zero exit with a stderr message.
    static func requireSuccess(_ result: ApplyResultDTO) throws {
        guard result.success else {
            FileHandle.standardError.write(Data("trayops: \(result.message ?? "operation failed")\n".utf8))
            throw ExitCode.failure
        }
    }
}
