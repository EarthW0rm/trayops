import Foundation

/// Resolves the absolute path of an external tool. The macOS GUI does not inherit
/// the shell PATH, so binaries are located explicitly (RN-DK-03).
public protocol BinaryLocator: Sendable {
    func path(for tool: String) -> String?
}

/// Searches a fixed set of well-known locations, then falls back to `which`.
public struct DefaultBinaryLocator: BinaryLocator {
    private let searchPaths: [String]

    public init(home: String = NSHomeDirectory()) {
        self.searchPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "\(home)/.rd/bin",
        ]
    }

    public func path(for tool: String) -> String? {
        for directory in searchPaths {
            let candidate = "\(directory)/\(tool)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return whichLookup(tool)
    }

    private func whichLookup(_ tool: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [tool]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let path = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }
}
