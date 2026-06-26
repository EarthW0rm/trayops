import Testing
import SwiftUI
import ViewInspector
@testable import TrayOpsUI
import TrayOpsCore

@Suite("GitHub Account UI")
@MainActor
struct GitHubAccountUITests {
    private func account() -> AccountDTO {
        AccountDTO(id: UUID(), label: "personal", gitName: "octocat", gitEmail: "octo@example.com", identityFile: "~/.ssh/id")
    }

    @Test("renders the consistent state summary")
    func rendersConsistentState() throws {
        let dto = account()
        let view = GitHubAccountContentView(
            state: .consistent(dto),
            accounts: [dto],
            selectedID: .constant(dto.id),
            onSet: {},
            onReconcile: {}
        )

        let text = try view.inspect().find(text: "Consistent: personal")
        #expect(try text.string() == "Consistent: personal")
    }

    @Test("renders the inconsistent state summary")
    func rendersInconsistentState() throws {
        let dto = account()
        let view = GitHubAccountContentView(
            state: .inconsistent(git: dto, ssh: nil),
            accounts: [dto],
            selectedID: .constant(dto.id),
            onSet: {},
            onReconcile: {}
        )

        _ = try view.inspect().find(text: "Inconsistent (git: personal, ssh: —)")
    }

    @Test("exposes Set and Reconcile and fires their actions")
    func firesActions() throws {
        var didSet = false
        var didReconcile = false
        let view = GitHubAccountContentView(
            state: .unknown,
            accounts: [],
            selectedID: .constant(nil),
            onSet: { didSet = true },
            onReconcile: { didReconcile = true }
        )

        try view.inspect().find(button: "Set").tap()
        try view.inspect().find(button: "Reconcile").tap()

        #expect(didSet)
        #expect(didReconcile)
    }
}
