import Foundation

/// Fulfills exactly one ``Request`` type (SRP). The Mediator resolves the handler
/// for an incoming request by the request's concrete type.
public protocol RequestHandler {
    associatedtype R: Request
    func handle(_ request: R) async throws -> R.Output
}
