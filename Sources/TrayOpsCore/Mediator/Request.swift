import Foundation

/// A unit of work sent through the ``Mediator``. Each request declares the type
/// of result it produces. Requests are the public boundary between frontends
/// (GUI/CLI) and the domain: frontends emit requests and receive outputs without
/// knowing the handlers or services that fulfill them.
public protocol Request {
    associatedtype Output
}
