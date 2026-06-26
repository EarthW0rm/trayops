import Foundation

/// Activates exactly one `IdentityFile` for a host in `~/.ssh/config`, commenting
/// out the others (RN-GH-02/07). Only the `IdentityFile` **path** is handled —
/// never the key contents (RN-GH-08).
public protocol SSHConfigService {
    func activeIdentityFile(host: String) async throws -> String?
    func activateIdentity(path: String, host: String) async throws
}

public enum SSHConfigError: Error, Equatable {
    /// `path`/`host` contained a newline or carriage return (config injection).
    case invalidValue(String)
}

/// Pure, IO-free transformer for `~/.ssh/config`. Keeps the parsing/normalization
/// fully unit-testable; the service wraps it with atomic file IO.
public enum SSHConfigRewriter {
    /// Returns the single active (uncommented) `IdentityFile` across every block
    /// that matches the host.
    public static func activeIdentityFile(host: String, in content: String) -> String? {
        let lines = content.components(separatedBy: "\n")
        for block in hostBlocks(matching: host, in: lines) {
            for index in (block.start + 1)..<block.end {
                if let parsed = parseIdentityFile(lines[index]), !parsed.commented {
                    return parsed.value
                }
            }
        }
        return nil
    }

    /// Ensures `path` is the only active `IdentityFile` for the host, commenting
    /// every other `IdentityFile` in **all** matching blocks and preserving every
    /// unrelated line. Creates the host block (or the whole file) when missing.
    /// Deterministic ⇒ idempotent.
    public static func activate(path: String, host: String, in content: String) -> String {
        var lines = content.isEmpty ? [] : content.components(separatedBy: "\n")

        let blocks = hostBlocks(matching: host, in: lines)
        guard let first = blocks.first else {
            return appendBlock(path: path, host: host, to: content)
        }

        let indent = blocks
            .flatMap { ($0.start + 1)..<$0.end }
            .compactMap { parseIdentityFile(lines[$0]) != nil ? leadingWhitespace(lines[$0]) : nil }
            .first ?? "    "

        // Comment out every IdentityFile in every matching block.
        for block in blocks {
            for index in (block.start + 1)..<block.end where parseIdentityFile(lines[index]) != nil {
                let value = parseIdentityFile(lines[index])!.value
                lines[index] = "\(indent)# IdentityFile \(value)"
            }
        }

        // Activate `path` in the first matching block (reuse an existing line or insert).
        var activated = false
        for index in (first.start + 1)..<first.end {
            if let parsed = parseIdentityFile(lines[index]), parsed.value == path {
                lines[index] = "\(indent)IdentityFile \(path)"
                activated = true
                break
            }
        }
        if !activated {
            lines.insert("\(indent)IdentityFile \(path)", at: first.start + 1)
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Parsing helpers

    private static func hostBlocks(matching host: String, in lines: [String]) -> [(start: Int, end: Int)] {
        var blocks: [(start: Int, end: Int)] = []
        var index = 0
        while index < lines.count {
            if isHostLine(lines[index]), hostPatterns(lines[index]).contains(host) {
                let end = blockEnd(after: index, in: lines)
                blocks.append((index, end))
                index = end
            } else {
                index += 1
            }
        }
        return blocks
    }

    private static func blockEnd(after start: Int, in lines: [String]) -> Int {
        for index in (start + 1)..<lines.count where isHostLine(lines[index]) {
            return index
        }
        return lines.count
    }

    private static func leadingWhitespace(_ line: String) -> String {
        String(line.prefix { $0 == " " || $0 == "\t" })
    }

    private static func isHostLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
        return trimmed == "host" || trimmed.hasPrefix("host ") || trimmed.hasPrefix("host\t")
    }

    private static func hostPatterns(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let rest = trimmed.dropFirst("Host".count).trimmingCharacters(in: .whitespaces)
        return rest.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
    }

    private static func parseIdentityFile(_ line: String) -> (commented: Bool, value: String)? {
        var text = line.trimmingCharacters(in: .whitespaces)
        var commented = false
        if text.hasPrefix("#") {
            commented = true
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        guard text.lowercased().hasPrefix("identityfile") else { return nil }
        let value = text.dropFirst("IdentityFile".count).trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }
        return (commented, String(value))
    }

    private static func appendBlock(path: String, host: String, to content: String) -> String {
        let block = "Host \(host)\n    IdentityFile \(path)\n"
        guard !content.isEmpty else { return block }
        var prefix = content
        if !prefix.hasSuffix("\n") { prefix += "\n" }
        if !prefix.hasSuffix("\n\n") { prefix += "\n" }
        return prefix + block
    }
}

/// Atomic, permission-preserving `~/.ssh/config` writer over the pure rewriter.
public struct DefaultSSHConfigService: SSHConfigService {
    private let configPath: String

    public init(configPath: String) {
        self.configPath = configPath
    }

    public func activeIdentityFile(host: String) async throws -> String? {
        SSHConfigRewriter.activeIdentityFile(host: host, in: try readConfig())
    }

    public func activateIdentity(path: String, host: String) async throws {
        try reject(newlinesIn: path)
        try reject(newlinesIn: host)
        let updated = SSHConfigRewriter.activate(path: path, host: host, in: try readConfig())
        try writeAtomic(updated)
    }

    private func reject(newlinesIn value: String) throws {
        if value.contains("\n") || value.contains("\r") {
            throw SSHConfigError.invalidValue(value)
        }
    }

    /// Returns "" only when the file is genuinely absent; a present-but-unreadable
    /// file throws instead of being silently overwritten (RN-GH-07).
    private func readConfig() throws -> String {
        guard FileManager.default.fileExists(atPath: configPath) else { return "" }
        return try String(contentsOfFile: configPath, encoding: .utf8)
    }

    private func writeAtomic(_ content: String) throws {
        let url = URL(fileURLWithPath: configPath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(content.utf8).write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
