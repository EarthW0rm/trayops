import Foundation

/// A typed snapshot of a ``Feature``'s current state. Each Feature defines its own
/// concrete state type. `Sendable` so snapshots can cross concurrency boundaries.
public protocol FeatureState: Sendable {}

/// Declarative description of a CLI command exposed by a ``Feature``. Used to list
/// the available operations (GUI/CLI parity); the concrete CLI wiring lives in the
/// CLI frontend, which dispatches the equivalent ``Request`` through the Mediator.
public struct FeatureCommand: Sendable, Equatable {
    public let name: String
    public let abstract: String

    public init(name: String, abstract: String) {
        self.name = name
        self.abstract = abstract
    }
}

/// A pluggable platform unit. Adding a new Function means implementing `Feature`
/// (and ``Reconcilable`` when it has a desired state) and registering it — the
/// core, Mediator, poller, reconcile-all, and frontends do not change (RN-P-07).
public protocol Feature: AnyObject, Identifiable {
    var id: String { get }
    var title: String { get }
    /// SF Symbol name (string only — the core never imports SwiftUI).
    var systemImage: String { get }

    /// Registers the Feature's use-case handlers on the Mediator (OCP).
    func registerHandlers(on mediator: Mediator)

    /// Declarative description of the CLI commands this Feature exposes.
    func commands() -> [FeatureCommand]

    /// The single state-refresh method (RN-P-01). Failures are surfaced as an
    /// "unavailable" state by the caller, never as a thrown error here.
    func refresh() async -> any FeatureState
}

/// Optional capability for Functions that have a desired state to reapply.
/// GitHub Account adopts it; Docker Control does not.
public protocol Reconcilable {
    func reconcile() async throws
}
