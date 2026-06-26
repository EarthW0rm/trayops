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

        let indices = blocks.flatMap { ($0.start + 1)..<$0.end }
        // Prefer the indentation of an existing IdentityFile; otherwise inherit the
        // real indentation (tab vs spaces) of the first indented line in the block,
        // falling back to four spaces only when the block has no indented line.
        let identityIndent =
            indices
            .first { parseIdentityFile(lines[$0]) != nil }
            .map { leadingWhitespace(lines[$0]) }
        let blockIndent =
            indices
            .first { !leadingWhitespace(lines[$0]).isEmpty }
            .map { leadingWhitespace(lines[$0]) }
        let indent = identityIndent ?? blockIndent ?? "    "

        // Comment out every IdentityFile in every matching block.
        for block in blocks {
            for index in (block.start + 1)..<block.end where parseIdentityFile(lines[index]) != nil {
                let value = parseIdentityFile(lines[index])!.value
                lines[index] = "\(indent)# IdentityFile \(formatIdentityValue(value))"
            }
        }

        // Activate `path` in the first matching block (reuse an existing line or insert).
        var activated = false
        for index in (first.start + 1)..<first.end {
            if let parsed = parseIdentityFile(lines[index]), parsed.value == path {
                lines[index] = "\(indent)IdentityFile \(formatIdentityValue(path))"
                activated = true
                break
            }
        }
        if !activated {
            lines.insert("\(indent)IdentityFile \(formatIdentityValue(path))", at: first.start + 1)
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Parsing helpers

    private static func hostBlocks(matching host: String, in lines: [String]) -> [(start: Int, end: Int)] {
        var blocks: [(start: Int, end: Int)] = []
        var index = 0
        while index < lines.count {
            if isHostLine(lines[index]),
                hostPatterns(lines[index]).contains(where: { matchesHost(pattern: $0, host: host) })
            {
                let end = blockEnd(after: index, in: lines)
                blocks.append((index, end))
                index = end
            } else {
                index += 1
            }
        }
        return blocks
    }

    /// A block ends at the next directive that opens a new context — both `Host`
    /// and `Match` start a fresh block in SSH config, so an `IdentityFile` living
    /// inside a `Match` must not be attributed to the preceding `Host`.
    private static func blockEnd(after start: Int, in lines: [String]) -> Int {
        for index in (start + 1)..<lines.count where isBlockStart(lines[index]) {
            return index
        }
        return lines.count
    }

    private static func leadingWhitespace(_ line: String) -> String {
        String(line.prefix { $0 == " " || $0 == "\t" })
    }

    private static func isBlockStart(_ line: String) -> Bool {
        isHostLine(line) || isMatchLine(line)
    }

    private static func isHostLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
        return trimmed == "host" || trimmed.hasPrefix("host ") || trimmed.hasPrefix("host\t")
    }

    private static func isMatchLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
        return trimmed == "match" || trimmed.hasPrefix("match ") || trimmed.hasPrefix("match\t")
    }

    /// Host matching honours SSH glob semantics (`*`, `?`) via `fnmatch`, so a
    /// concrete host is recognised by patterns like `Host *` or `Host *.github.com`
    /// and no duplicate block is created for an already-covered host.
    private static func matchesHost(pattern: String, host: String) -> Bool {
        pattern == host || fnmatch(pattern, host, 0) == 0
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
        var value = String(text.dropFirst("IdentityFile".count).trimmingCharacters(in: .whitespaces))
        guard !value.isEmpty else { return nil }
        // SSH accepts a double-quoted path so values may contain spaces. Capture the
        // unquoted path; `formatIdentityValue` re-adds quotes on write when needed.
        // SSH has no inline-comment syntax, so the rest of the line is the value.
        if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
            value = String(value.dropFirst().dropLast())
        }
        return (commented, value)
    }

    /// Re-quotes a path on write only when it contains a space, mirroring how SSH
    /// requires quoting for paths with whitespace.
    private static func formatIdentityValue(_ value: String) -> String {
        value.contains(" ") ? "\"\(value)\"" : value
    }

    private static func appendBlock(path: String, host: String, to content: String) -> String {
        let block = "Host \(host)\n    IdentityFile \(formatIdentityValue(path))\n"
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

    /// Writes through a sibling temp file created with `0600` up front, then swaps
    /// it into place atomically. A plain `Data.write(.atomic)` + `chmod` would leave
    /// the final file briefly readable with default permissions (e.g. `0644`); here
    /// the destination is never observable with anything but `0600`.
    private func writeAtomic(_ content: String) throws {
        let url = URL(fileURLWithPath: configPath)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let tempURL = directory.appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        guard
            FileManager.default.createFile(
                atPath: tempURL.path,
                contents: Data(content.utf8),
                attributes: [.posixPermissions: 0o600]
            )
        else {
            throw CocoaError(.fileWriteUnknown)
        }
        // Defensive: re-assert 0600 in case the umask widened createFile's attributes.
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tempURL.path)

        do {
            if FileManager.default.fileExists(atPath: url.path) {
                // `.usingNewMetadataOnly` keeps the temp file's 0600 instead of
                // inheriting any prior (possibly wider) permissions.
                _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL, options: .usingNewMetadataOnly)
            } else {
                try FileManager.default.moveItem(at: tempURL, to: url)
            }
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }
    }
}
