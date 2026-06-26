import TrayOpsCore

/// Deterministic ``BinaryLocator`` for tests: returns the mapped path for known
/// tools and nil otherwise (used to simulate an absent binary).
public struct StubBinaryLocator: BinaryLocator {
    private let paths: [String: String]

    public init(_ paths: [String: String]) {
        self.paths = paths
    }

    public func path(for tool: String) -> String? {
        paths[tool]
    }
}
