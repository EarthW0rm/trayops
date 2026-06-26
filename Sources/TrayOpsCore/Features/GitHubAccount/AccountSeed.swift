import Foundation

/// Resolves and decodes the unversioned seed file used on first run (RN-GH-05).
/// No personal data is ever hardcoded — the values live only in a local file.
public enum AccountSeed {
    public struct Entry: Codable, Equatable, Sendable {
        public let label: String
        public let gitName: String
        public let gitEmail: String
        public let identityFile: String
    }

    private struct File: Codable {
        let accounts: [Entry]
    }

    /// Resolution order: `TRAYOPS_SEED_PATH` env → `accounts.seed.json` in the
    /// current directory → `~/.config/trayops/accounts.seed.json`. Returns the
    /// first path that exists, or nil.
    public static func resolveURL(
        environment: [String: String],
        home: String,
        currentDirectory: String
    ) -> URL? {
        let candidates = [
            environment["TRAYOPS_SEED_PATH"],
            "\(currentDirectory)/accounts.seed.json",
            "\(home)/.config/trayops/accounts.seed.json",
        ].compactMap { $0 }

        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    /// Decodes the seed entries, or nil on a missing/invalid file (start empty).
    public static func load(from url: URL) -> [Entry]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(File.self, from: data).accounts
    }
}
