import Testing
import SwiftUI
import ViewInspector
@testable import TrayOpsUI
import TrayOpsCore
import TrayOpsTestSupport

@Suite("Root panel UI")
@MainActor
struct RootPanelUITests {
    @Test("renders the feature state published to the StateStore and a Reconcile All button")
    func rendersStateAndReconcileAll() throws {
        let test = try TestComposition()
        let dto = AccountDTO(
            id: UUID(), label: "personal", gitName: "octocat", gitEmail: "octo@example.com", identityFile: "~/.ssh/id")
        test.composition.stateStore.set("github-account", GitHubAccountState.consistent(dto))

        let view = RootPanelView(composition: test.composition)

        _ = try view.inspect().find(text: "Consistent: personal")
        _ = try view.inspect().find(button: "Reconcile All")
    }
}
