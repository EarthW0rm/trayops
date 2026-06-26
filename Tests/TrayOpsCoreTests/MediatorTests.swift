import Testing
import TrayOpsCore

@Suite("Mediator")
struct MediatorTests {
    private struct Ping: Request {
        typealias Output = String
        let value: String
    }

    private struct PingHandler: RequestHandler {
        func handle(_ request: Ping) async throws -> String {
            "pong:\(request.value)"
        }
    }

    @Test("dispatches a request to its registered handler")
    func dispatchesToHandler() async throws {
        let mediator = DefaultMediator()
        mediator.register(PingHandler())

        let output = try await mediator.send(Ping(value: "x"))

        #expect(output == "pong:x")
    }

    @Test("throws noHandler when no handler is registered")
    func throwsWhenNoHandler() async {
        let mediator = DefaultMediator()

        await #expect(throws: MediatorError.self) {
            _ = try await mediator.send(Ping(value: "x"))
        }
    }

    // Note: double-registration of a handler for the same Request type trips an
    // `assert` in `DefaultMediator.register`, which traps the process in debug
    // builds. Swift Testing cannot catch that trap, so there is intentionally no
    // test exercising it here; the single-registration path above stays valid.
}
