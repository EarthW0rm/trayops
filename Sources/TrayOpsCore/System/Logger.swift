import Foundation

/// Severity of a log entry.
public enum LogLevel: String, Sendable {
    case debug
    case info
    case warning
    case error
}

/// Minimal logging boundary. The core depends only on this protocol; production
/// writes to a file, tests use a no-op or a capturing logger.
public protocol Logger: Sendable {
    func log(_ level: LogLevel, _ message: String)
}

public extension Logger {
    func debug(_ message: String) { log(.debug, message) }
    func info(_ message: String) { log(.info, message) }
    func warning(_ message: String) { log(.warning, message) }
    func error(_ message: String) { log(.error, message) }
}

/// Discards every entry (default for tests and non-instrumented call sites).
public struct NullLogger: Logger {
    public init() {}
    public func log(_ level: LogLevel, _ message: String) {}
}

/// Appends timestamped entries to a log file for troubleshooting. Opens the file
/// with `O_APPEND` so the GUI and CLI processes can write concurrently without
/// clobbering each other; serialized by a lock within a process.
///
/// The file may contain executed commands (git/rdctl/docker) and their arguments —
/// i.e. local config values such as identities and key paths, never key contents.
/// It is created user-only (`0600`) under a `0700` directory.
public final class FileLogger: Logger, @unchecked Sendable {
    private let handle: FileHandle?
    private let lock = NSLock()
    private let formatter: ISO8601DateFormatter

    public init(fileURL: URL) {
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let descriptor = open(fileURL.path, O_WRONLY | O_APPEND | O_CREAT, 0o600)
        handle = descriptor >= 0 ? FileHandle(fileDescriptor: descriptor, closeOnDealloc: true) : nil
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    public func log(_ level: LogLevel, _ message: String) {
        guard let handle else { return }
        lock.lock()
        defer { lock.unlock() }
        let line = "\(formatter.string(from: Date())) [\(level.rawValue.uppercased())] \(message)\n"
        try? handle.write(contentsOf: Data(line.utf8))
    }
}
