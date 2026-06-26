import Testing
import Foundation
import TrayOpsCore
import TrayOpsTestSupport

@Suite("DefaultSSHConfigService (IO)")
struct SSHConfigServiceTests {
    @Test("writes with 0600 permissions and preserves unrelated content")
    func writesSecurelyAndPreserves() async throws {
        let sandbox = try Sandbox()
        try sandbox.writeSSHConfig("Host example.com\n    IdentityFile ~/.ssh/other\n")
        let ssh = DefaultSSHConfigService(configPath: sandbox.sshConfigPath)

        try await ssh.activateIdentity(path: "~/.ssh/id_a", host: "github.com")

        let attributes = try FileManager.default.attributesOfItem(atPath: sandbox.sshConfigPath)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)

        let content = sandbox.readSSHConfig() ?? ""
        #expect(content.contains("Host example.com"))
        #expect(content.contains("IdentityFile ~/.ssh/other"))
        #expect(try await ssh.activeIdentityFile(host: "github.com") == "~/.ssh/id_a")
    }

    @Test("is idempotent on disk")
    func idempotentOnDisk() async throws {
        let sandbox = try Sandbox()
        let ssh = DefaultSSHConfigService(configPath: sandbox.sshConfigPath)

        try await ssh.activateIdentity(path: "~/.ssh/id_a", host: "github.com")
        let first = sandbox.readSSHConfig()
        try await ssh.activateIdentity(path: "~/.ssh/id_a", host: "github.com")

        #expect(sandbox.readSSHConfig() == first)
    }

    @Test("rejects newline injection in the IdentityFile path")
    func rejectsInjection() async throws {
        let sandbox = try Sandbox()
        let ssh = DefaultSSHConfigService(configPath: sandbox.sshConfigPath)

        await #expect(throws: SSHConfigError.self) {
            try await ssh.activateIdentity(path: "~/.ssh/id\nProxyCommand /bin/sh", host: "github.com")
        }
    }
}
