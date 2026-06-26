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
}
