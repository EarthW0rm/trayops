import Foundation
import ArgumentParser
import TrayOpsCore

/// `trayops docker ...` — full parity with the GUI Docker Control Function.
struct DockerCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "docker",
        abstract: "Show and toggle the Docker engine (Rancher Desktop).",
        subcommands: [Status.self, Start.self, Shutdown.self]
    )
}

extension DockerCommand {
    struct Status: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status", abstract: "Show whether Docker is online or offline.")
        func run() async throws {
            let state = try await CLIRuntime.mediator.send(ResolveDockerState())
            print(state.summary)
        }
    }

    struct Start: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "start", abstract: "Start the Docker engine.")
        func run() async throws {
            try await CLIRuntime.mediator.send(DockerStart())
            print("Starting Docker…")
        }
    }

    struct Shutdown: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "shutdown", abstract: "Shut down the Docker engine.")
        func run() async throws {
            try await CLIRuntime.mediator.send(DockerShutdown())
            print("Shutting down Docker…")
        }
    }
}
