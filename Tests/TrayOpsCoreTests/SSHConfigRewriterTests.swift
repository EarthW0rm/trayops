import Testing
import TrayOpsCore

@Suite("SSHConfigRewriter")
struct SSHConfigRewriterTests {
    private let host = "github.com"

    @Test("creates the host block when the file is empty")
    func createsBlockWhenEmpty() {
        let output = SSHConfigRewriter.activate(path: "~/.ssh/id_a", host: host, in: "")

        #expect(output.contains("Host github.com"))
        #expect(SSHConfigRewriter.activeIdentityFile(host: host, in: output) == "~/.ssh/id_a")
    }

    @Test("appends the host block without destroying existing content")
    func appendsHostWhenMissing() {
        let existing = "Host example.com\n    User bob\n"

        let output = SSHConfigRewriter.activate(path: "~/.ssh/id_a", host: host, in: existing)

        #expect(output.contains("Host example.com"))
        #expect(output.contains("User bob"))
        #expect(SSHConfigRewriter.activeIdentityFile(host: host, in: output) == "~/.ssh/id_a")
    }

    @Test("inserts an IdentityFile when the host block has none")
    func insertsWhenNoIdentityFile() {
        let existing = "Host github.com\n    User git\n"

        let output = SSHConfigRewriter.activate(path: "~/.ssh/id_a", host: host, in: existing)

        #expect(output.contains("User git"))
        #expect(SSHConfigRewriter.activeIdentityFile(host: host, in: output) == "~/.ssh/id_a")
    }

    @Test("normalizes multiple IdentityFiles to a single active one")
    func normalizesMultipleIdentityFiles() {
        let existing = "Host github.com\n    IdentityFile ~/.ssh/id_a\n    IdentityFile ~/.ssh/id_b\n"

        let output = SSHConfigRewriter.activate(path: "~/.ssh/id_b", host: host, in: existing)

        #expect(SSHConfigRewriter.activeIdentityFile(host: host, in: output) == "~/.ssh/id_b")
        #expect(output.contains("# IdentityFile ~/.ssh/id_a"))
    }

    @Test("is idempotent — applying twice yields an identical file")
    func isIdempotent() {
        let existing = "Host github.com\n    IdentityFile ~/.ssh/id_a\n    IdentityFile ~/.ssh/id_b\n"

        let first = SSHConfigRewriter.activate(path: "~/.ssh/id_a", host: host, in: existing)
        let second = SSHConfigRewriter.activate(path: "~/.ssh/id_a", host: host, in: first)

        #expect(first == second)
    }

    @Test("preserves unrelated hosts")
    func preservesUnrelatedHosts() {
        let existing = "Host example.com\n    IdentityFile ~/.ssh/other\n\nHost github.com\n    IdentityFile ~/.ssh/id_a\n"

        let output = SSHConfigRewriter.activate(path: "~/.ssh/id_b", host: host, in: existing)

        #expect(output.contains("Host example.com"))
        #expect(output.contains("IdentityFile ~/.ssh/other"))
        #expect(SSHConfigRewriter.activeIdentityFile(host: host, in: output) == "~/.ssh/id_b")
    }

    @Test("returns nil when no host block is present")
    func nilWhenHostMissing() {
        #expect(SSHConfigRewriter.activeIdentityFile(host: host, in: "Host example.com\n") == nil)
    }

    @Test("normalizes across duplicate host blocks to exactly one active")
    func normalizesAcrossDuplicateHostBlocks() {
        let existing = "Host github.com\n    IdentityFile ~/.ssh/id_a\n\nHost github.com\n    IdentityFile ~/.ssh/id_b\n"

        let output = SSHConfigRewriter.activate(path: "~/.ssh/id_a", host: host, in: existing)

        #expect(SSHConfigRewriter.activeIdentityFile(host: host, in: output) == "~/.ssh/id_a")
        #expect(output.contains("# IdentityFile ~/.ssh/id_b"))
        // Exactly one uncommented IdentityFile remains for the host.
        let activeCount = output
            .components(separatedBy: "\n")
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.hasPrefix("IdentityFile")
            }
            .count
        #expect(activeCount == 1)
    }
}
