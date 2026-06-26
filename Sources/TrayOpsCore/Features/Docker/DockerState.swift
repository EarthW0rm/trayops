import Foundation

/// State of the Docker Control Function.
public enum DockerState: FeatureState, Equatable {
    case online
    case offline
    /// A start/shutdown is in progress; converges on the next refresh (RN-DK-04).
    case transitioning
    /// `rdctl`/`docker` absent or failed — actions are disabled (RN-P-08).
    case unavailable(reason: String)

    /// Human-readable one-line summary shared by the GUI and the CLI.
    public var summary: String {
        switch self {
        case .online: return "Online"
        case .offline: return "Offline"
        case .transitioning: return "Transitioning…"
        case .unavailable(let reason): return "Unavailable: \(reason)"
        }
    }
}
