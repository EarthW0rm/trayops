import Foundation

/// Controls the Docker engine via Rancher Desktop. Binaries are resolved by
/// absolute path (RN-DK-03); the GUI does not inherit the shell PATH.
public protocol DockerService {
    func status() async -> DockerState
    func start() async throws
    func shutdown() async throws
}

public enum DockerError: Error, Equatable {
    case binaryNotFound(String)
    case commandFailed(exitCode: Int32, stderr: String)
}

public struct DefaultDockerService: DockerService {
    private let runner: ProcessRunner
    private let locator: BinaryLocator

    public init(runner: ProcessRunner, locator: BinaryLocator) {
        self.runner = runner
        self.locator = locator
    }

    /// `docker info` exit 0 ⇒ online, ≠ 0 ⇒ offline; binary absent ⇒ unavailable.
    public func status() async -> DockerState {
        guard let docker = locator.path(for: "docker") else {
            return .unavailable(reason: "docker binary not found")
        }
        do {
            let output = try await runner.run(docker, ["info"])
            return output.exitCode == 0 ? .online : .offline
        } catch {
            return .unavailable(reason: "\(error)")
        }
    }

    public func start() async throws {
        try await runRdctl(["start"])
    }

    public func shutdown() async throws {
        try await runRdctl(["shutdown"])
    }

    private func runRdctl(_ args: [String]) async throws {
        guard let rdctl = locator.path(for: "rdctl") else {
            throw DockerError.binaryNotFound("rdctl")
        }
        let output = try await runner.run(rdctl, args)
        guard output.exitCode == 0 else {
            throw DockerError.commandFailed(exitCode: output.exitCode, stderr: output.stderr)
        }
    }
}
