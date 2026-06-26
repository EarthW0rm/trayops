import Foundation

/// Anchor type used to locate the test bundle via `Bundle(for:)`. Lives in the
/// support module, which is statically linked into the test bundle, so the
/// returned bundle is the `.xctest` itself regardless of how it was loaded
/// (works under both the XCTest and the Swift Testing runners).
public final class TestBundleAnchor {}

/// Locates the built `trayops` CLI binary for E2E tests (run via `Process`).
public enum TestBinary {
    public static var trayops: URL {
        productsDirectory.appendingPathComponent("trayops")
    }

    private static var productsDirectory: URL {
        // The .xctest bundle sits next to the product binaries in the build dir.
        Bundle(for: TestBundleAnchor.self).bundleURL.deletingLastPathComponent()
    }
}
