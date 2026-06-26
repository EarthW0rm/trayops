import Foundation

/// Canonical Feature identifiers, shared by the core, the frontends and the tests
/// to avoid stringly-typed coupling across modules.
public enum FeatureID {
    public static let gitHubAccount = "github-account"
    public static let docker = "docker"
}
