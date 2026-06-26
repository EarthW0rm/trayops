import SwiftUI
import AppKit
import TrayOpsCore
import TrayOpsUI

/// GUI frontend: a thin `@main` shell that builds the composition and shows the
/// menu bar panel. No Dock icon (`.accessory` activation policy).
@main
struct TrayOpsApp: App {
    @State private var composition: AppComposition

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
        do {
            let composition = try AppComposition.live()
            composition.poller.start()  // periodic state refresh (RN-P-02)
            _composition = State(initialValue: composition)
        } catch {
            fatalError("TrayOps failed to initialize: \(error)")
        }
    }

    var body: some Scene {
        MenuBarExtra("TrayOps", systemImage: "switch.2") {
            RootPanelView(composition: composition)
        }
        .menuBarExtraStyle(.window)
    }
}
