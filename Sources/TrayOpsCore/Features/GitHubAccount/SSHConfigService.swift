import Foundation

/// Activates exactly one `IdentityFile` for a host in `~/.ssh/config`, commenting
/// out the others (RN-GH-02/07). Only the `IdentityFile` **path** is handled —
/// never the key contents (RN-GH-08).
public protocol SSHConfigService {
    func activeIdentityFile(host: String) async throws -> String?
    func activateIdentity(path: String, host: String) async throws
}

/// Pure, IO-free transformer for `~/.ssh/config`. Keeps the parsing/normalization
/// fully unit-testable; the service wraps it with atomic file IO.
public enum SSHConfigRewriter {
    /// Returns the single active (uncommented) `IdentityFile` of the host block.
    public static func activeIdentityFile(host: String, in content: String) -> String? {
        let lines = content.components(separatedBy: "\n")
        guard let start = lines.firstIndex(where: { isHostLine($0) && hostPatterns($0).contains(host) }) else {
            return nil
        }
        let end = blockEnd(after: start, in: lines)
        for index in (start + 1)..<end {
            if let parsed = parseIdentityFile(lines[index]), !parsed.commented {
                return parsed.value
            }
        }
        return nil
    }

    /// Ensures `path` is the only active `IdentityFile` of the host block,
    /// commenting the others and preserving every unrelated line. Creates the
    /// host block (or the whole file) when missing. Deterministic ⇒ idempotent.
    public static func activate(path: String, host: String, in content: String) -> String {
        var lines = content.isEmpty ? [] : content.components(separatedBy: "\n")

        guard let start = lines.firstIndex(where: { isHostLine($0) && hostPatterns($0).contains(host) }) else {
            return appendBlock(path: path, host: host, to: content)
        }

        let end = blockEnd(after: start, in: lines)
        let indent = lines[(start + 1)..<end]
            .compactMap { parseIdentityFile($0) != nil ? leadingWhitespace($0) : nil }
            .first ?? "    "

        var activeAssigned = false
        for index in (start + 1)..<end {
            guard let parsed = parseIdentityFile(lines[index]) else { continue }
            if parsed.value == path, !activeAssigned {
                lines[index] = "\(indent)IdentityFile \(path)"
                activeAssigned = true
            } else {
                lines[index] = "\(indent)# IdentityFile \(parsed.value)"
            }
        }

        if !activeAssigned {
            lines.insert("\(indent)IdentityFile \(path)", at: start + 1)
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Parsing helpers

    private static func blockEnd(after start: Int, in lines: [String]) -> Int {
        let rest = (start + 1)..<lines.count
        for index in rest where isHostLine(lines[index]) {
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
        SSHConfigRewriter.activeIdentityFile(host: host, in: readConfig())
    }

    public func activateIdentity(path: String, host: String) async throws {
        let updated = SSHConfigRewriter.activate(path: path, host: host, in: readConfig())
        try writeAtomic(updated)
    }

    private func readConfig() -> String {
        (try? String(contentsOfFile: configPath, encoding: .utf8)) ?? ""
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
