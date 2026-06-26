import Testing
import Foundation
import TrayOpsCore

@Suite("JSONAccountStore and seed")
struct AccountStoreTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("trayops-accounts-\(UUID().uuidString).json")
    }

    private func writeSeedFixture() throws -> URL {
        let url = tempURL()
        let json = """
        { "accounts": [
            { "label": "personal", "gitName": "octocat", "gitEmail": "octo@example.com", "identityFile": "~/.ssh/id_personal" },
            { "label": "work", "gitName": "octocat-work", "gitEmail": "octo@work.example.com", "identityFile": "~/.ssh/id_work" }
        ] }
        """
        try json.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test("seeds from the file then stays idempotent")
    func seedsThenIdempotent() throws {
        let seedURL = try writeSeedFixture()
        let store = JSONAccountStore(url: tempURL())

        try store.seedIfEmpty(from: seedURL)
        #expect(try store.all().count == 2)

        try store.seedIfEmpty(from: seedURL)
        #expect(try store.all().count == 2)
    }

    @Test("starts empty when no seed is available")
    func startsEmptyWhenNoSeed() throws {
        let store = JSONAccountStore(url: tempURL())

        try store.seedIfEmpty(from: nil)

        #expect(try store.all().isEmpty)
    }

    @Test("rejects an empty required field")
    func rejectsEmptyField() {
        let store = JSONAccountStore(url: tempURL())

        #expect(throws: AccountValidationError.self) {
            try store.add(Account(label: "", gitName: "x", gitEmail: "y@e.com", identityFile: "~/.ssh/id"))
        }
    }

    @Test("persists across store instances")
    func persistsAcrossInstances() throws {
        let url = tempURL()
        let first = JSONAccountStore(url: url)
        try first.add(Account(label: "personal", gitName: "octocat", gitEmail: "octo@example.com", identityFile: "~/.ssh/id"))

        let second = JSONAccountStore(url: url)
        #expect(try second.all().count == 1)
        #expect(try second.all().first?.label == "personal")
    }
}

@Suite("AccountSeed")
struct AccountSeedTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("trayops-seed-\(UUID().uuidString).json")
    }

    @Test("resolves the env path first")
    func resolvesEnvFirst() throws {
        let url = tempURL()
        try "{}".write(to: url, atomically: true, encoding: .utf8)

        let resolved = AccountSeed.resolveURL(
            environment: ["TRAYOPS_SEED_PATH": url.path],
            home: "/nonexistent-home",
            currentDirectory: "/nonexistent-cwd"
        )

        #expect(resolved == url)
    }

    @Test("returns nil when no candidate exists")
    func nilWhenNoneExist() {
        let resolved = AccountSeed.resolveURL(
            environment: [:],
            home: "/nonexistent-home-\(UUID().uuidString)",
            currentDirectory: "/nonexistent-cwd-\(UUID().uuidString)"
        )
        #expect(resolved == nil)
    }

    @Test("loads valid entries and returns nil on invalid JSON")
    func loadsAndRejects() throws {
        let valid = tempURL()
        try #"{ "accounts": [ { "label": "p", "gitName": "n", "gitEmail": "e@e.com", "identityFile": "~/.ssh/id" } ] }"#
            .write(to: valid, atomically: true, encoding: .utf8)
        #expect(AccountSeed.load(from: valid)?.count == 1)

        let invalid = tempURL()
        try "not json".write(to: invalid, atomically: true, encoding: .utf8)
        #expect(AccountSeed.load(from: invalid) == nil)
    }
}
