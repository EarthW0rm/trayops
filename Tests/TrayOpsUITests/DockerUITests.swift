import Testing
import SwiftUI
import ViewInspector
@testable import TrayOpsUI
import TrayOpsCore

@Suite("Docker UI")
@MainActor
struct DockerUITests {
    @Test("offline shows Start and fires DockerStart")
    func offlineShowsStart() throws {
        var started = false
        let view = DockerContentView(state: .offline, onStart: { started = true }, onShutdown: {})

        try view.inspect().find(button: "Start").tap()

        #expect(started)
    }

    @Test("online shows Shut Down and fires DockerShutdown")
    func onlineShowsShutDown() throws {
        var didShutDown = false
        let view = DockerContentView(state: .online, onStart: {}, onShutdown: { didShutDown = true })

        try view.inspect().find(button: "Shut Down").tap()

        #expect(didShutDown)
    }

    @Test("unavailable shows the reason and no action button")
    func unavailableShowsReason() throws {
        let view = DockerContentView(
            state: .unavailable(reason: "docker binary not found"), onStart: {}, onShutdown: {})

        _ = try view.inspect().find(text: "Unavailable: docker binary not found")
        #expect(throws: Error.self) {
            _ = try view.inspect().find(button: "Start")
        }
    }

    @Test("action error message is rendered")
    func actionErrorIsRendered() throws {
        let view = DockerContentView(
            state: .offline,
            errorMessage: "rdctl command failed (exit code 1)",
            onStart: {},
            onShutdown: {}
        )

        _ = try view.inspect().find(text: "rdctl command failed (exit code 1)")
    }
}
