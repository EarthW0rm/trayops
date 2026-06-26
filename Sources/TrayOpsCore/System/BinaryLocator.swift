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
        guard !path.isEmpty else { return nil }
        // `which` resolves via the inherited PATH, which the GUI must not trust:
        // a polluted PATH could point a tool name at a malicious binary
        // (RN-DK-03). Accept the result only when it lives under one of the
        // trusted searchPaths; otherwise reject it (defense against PATH injection).
        guard isUnderTrustedSearchPath(path) else { return nil }
        return path
    }

    private func isUnderTrustedSearchPath(_ path: String) -> Bool {
        searchPaths.contains { directory in
            path == directory || path.hasPrefix("\(directory)/")
        }
    }
}
