import Foundation

// Human-readable descriptions for the core error types. Conforming to
// `LocalizedError` makes `error.localizedDescription` (and SwiftUI/CLI string
// interpolation that surfaces it) render a clear message instead of the raw
// enum case. The core stays frontend-agnostic: these are plain strings consumed
// equally by the GUI and the CLI.

extension GitConfigError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "git executable could not be located."
        case let .commandFailed(exitCode, stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = detail.isEmpty ? "" : ": \(detail)"
            return "git command failed (exit code \(exitCode))\(suffix)"
        }
    }
}

extension SSHConfigError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .invalidValue(value):
            return "Invalid SSH config value (contains a newline or carriage return): \(value)"
        }
    }
}

extension DockerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .binaryNotFound(name):
            return "\(name) executable could not be located."
        case let .commandFailed(exitCode, stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = detail.isEmpty ? "" : ": \(detail)"
            return "Docker command failed (exit code \(exitCode))\(suffix)"
        }
    }
}

extension ProcessRunnerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .timedOut(executable, seconds):
            return "\(executable) timed out after \(Int(seconds))s and was terminated."
        }
    }
}

extension MediatorError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .noHandler(request):
            return "No handler is registered for request \(request)."
        case let .outputTypeMismatch(request):
            return "Handler for request \(request) returned an unexpected output type."
        }
    }
}

extension AccountStoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "Account not found in the store."
        case .duplicateID:
            return "An account with the same identifier already exists."
        }
    }
}
