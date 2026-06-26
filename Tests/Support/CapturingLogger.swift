import Foundation
import TrayOpsCore

/// In-memory ``Logger`` for tests: records every entry as "[level] message".
public final class CapturingLogger: Logger, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    public init() {}

    public func log(_ level: LogLevel, _ message: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.append("[\(level.rawValue)] \(message)")
    }

    public var lines: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
