import Foundation

/// Ordered collection of the platform's Functions. Registers all Feature handlers
/// on the Mediator at bootstrap. The single place that knows the concrete Features.
public final class FeatureRegistry {
    public private(set) var features: [any Feature]

    public init(features: [any Feature] = []) {
        self.features = features
    }

    public func register(_ feature: any Feature) {
        features.append(feature)
    }

    /// Registers every Feature's handlers on the Mediator.
    public func registerAll(on mediator: Mediator) {
        for feature in features {
            feature.registerHandlers(on: mediator)
        }
    }
}
