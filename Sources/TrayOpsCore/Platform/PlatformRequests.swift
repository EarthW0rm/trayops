import Foundation

/// Refresh the state of all Functions (poller and on-demand).
public struct RefreshAll: Request {
    public typealias Output = Void
    public init() {}
}

/// Reconcile every reconcilable Function and report the outcome.
public struct ReconcileAll: Request {
    public typealias Output = ReconcileReportDTO
    public init() {}
}

/// Consolidated result of a Reconcile All run (one entry per reconcilable Function).
public struct ReconcileReportDTO: Sendable, Equatable {
    public struct Entry: Sendable, Equatable {
        public let featureID: String
        public let success: Bool
        public let message: String?

        public init(featureID: String, success: Bool, message: String?) {
            self.featureID = featureID
            self.success = success
            self.message = message
        }
    }

    public let entries: [Entry]

    public init(entries: [Entry]) {
        self.entries = entries
    }

    public var allSucceeded: Bool {
        entries.allSatisfy(\.success)
    }
}
