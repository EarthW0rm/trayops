import Foundation

/// Resolve the current Docker state.
public struct ResolveDockerState: Request {
    public typealias Output = DockerState
    public init() {}
}

/// Start the Docker engine (`rdctl start`).
public struct DockerStart: Request {
    public typealias Output = Void
    public init() {}
}

/// Shut down the Docker engine (`rdctl shutdown`).
public struct DockerShutdown: Request {
    public typealias Output = Void
    public init() {}
}
