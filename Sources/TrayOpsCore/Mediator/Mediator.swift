import Foundation

/// Errors raised by the command bus.
public enum MediatorError: Error, Equatable {
    /// No handler was registered for the dispatched request type.
    case noHandler(String)
    /// A handler was found but its output type did not match the request's
    /// (a registration bug, not a missing handler).
    case outputTypeMismatch(String)
}

/// Command bus: frontends `send` a ``Request`` and receive its `Output`.
/// Domain-agnostic — it knows nothing about the concrete requests or handlers.
public protocol Mediator: AnyObject {
    func register<H: RequestHandler>(_ handler: H)
    func send<R: Request>(_ request: R) async throws -> R.Output
}

/// Default in-process Mediator. Resolves handlers by the `Request`'s concrete
/// type (`ObjectIdentifier`). Registration happens once at composition time, so
/// dispatch is read-only at runtime.
public final class DefaultMediator: Mediator {
    private var handlers: [ObjectIdentifier: (Any) async throws -> Any] = [:]

    public init() {}

    public func register<H: RequestHandler>(_ handler: H) {
        let key = ObjectIdentifier(H.R.self)
        handlers[key] = { anyRequest in
            guard let request = anyRequest as? H.R else {
                throw MediatorError.noHandler(String(describing: type(of: anyRequest)))
            }
            return try await handler.handle(request)
        }
    }

    public func send<R: Request>(_ request: R) async throws -> R.Output {
        let key = ObjectIdentifier(R.self)
        guard let handler = handlers[key] else {
            throw MediatorError.noHandler(String(describing: R.self))
        }
        let result = try await handler(request)
        guard let output = result as? R.Output else {
            throw MediatorError.outputTypeMismatch(String(describing: R.self))
        }
        return output
    }
}
