import Foundation
import ArgumentParser
import TrayOpsCore

/// `trayops status` — refresh and print every Function's state.
struct StatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Refresh and print the state of all Functions."
    )

    func run() async throws {
        _ = try await CLIRuntime.mediator.send(RefreshAll())
        let composition = CLIRuntime.composition
        for feature in composition.registry.features {
            let state = composition.stateStore.snapshot(for: feature.id)
            print("\(feature.title): \(StateSummary.describe(state))")
        }
    }
}

/// `trayops reconcile-all` — reconcile reconcilable Functions and print the report.
struct ReconcileAllCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reconcile-all",
        abstract: "Reconcile all reconcilable Functions and report the result."
    )

    func run() async throws {
        let report = try await CLIRuntime.mediator.send(ReconcileAll())
        if report.entries.isEmpty {
            print("No reconcilable Functions.")
        }
        for entry in report.entries {
            print("\(entry.featureID): \(entry.success ? "ok" : "failed — \(entry.message ?? "unknown")")")
        }
        if !report.allSucceeded {
            throw ExitCode.failure
        }
    }
}

/// Renders a Function state into a one-line CLI summary. Extended per Feature.
enum StateSummary {
    static func describe(_ state: (any FeatureState)?) -> String {
        switch state {
        case let gitHub as GitHubAccountState:
            return gitHub.summary
        default:
            return "—"
        }
    }
}
