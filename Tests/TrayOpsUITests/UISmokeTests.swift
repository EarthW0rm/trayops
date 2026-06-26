import Testing
import SwiftUI
import ViewInspector
@testable import TrayOpsUI
import TrayOpsCore
import TrayOpsTestSupport

@Suite("UI smoke")
@MainActor
struct UISmokeTests {
    @Test("empty panel shows the placeholder text")
    func emptyPanelShowsPlaceholder() throws {
        let test = try TestComposition()
        let view = RootPanelView(composition: test.composition)

        let text = try view.inspect().find(text: "No functions registered")

        #expect(try text.string() == "No functions registered")
    }
}
