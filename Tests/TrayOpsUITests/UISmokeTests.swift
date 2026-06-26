import Testing
import SwiftUI
import ViewInspector
@testable import TrayOpsUI
import TrayOpsCore
import TrayOpsTestSupport

@Suite("UI smoke")
@MainActor
struct UISmokeTests {
    @Test("root panel renders the registered feature and a Quit button")
    func rootPanelRenders() throws {
        let test = try TestComposition()
        let view = RootPanelView(composition: test.composition)

        // The GitHub Account Function's panel is rendered…
        _ = try view.inspect().find(text: "GitHub Account")
        // …alongside the platform's Quit control.
        _ = try view.inspect().find(button: "Quit TrayOps")
    }
}
