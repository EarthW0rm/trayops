import Foundation

/// Periodically dispatches ``RefreshAll`` so the platform state stays current
/// (every 15s in production; the interval is injectable for tests).
public final class StatePoller {
    private let mediator: Mediator
    private let intervalSeconds: TimeInterval
    private var task: Task<Void, Never>?

    public init(intervalSeconds: TimeInterval = 15, mediator: Mediator) {
        self.intervalSeconds = intervalSeconds
        self.mediator = mediator
    }

    public func start() {
        stop()
        let mediator = self.mediator
        let nanoseconds = UInt64(intervalSeconds * 1_000_000_000)
        task = Task {
            while !Task.isCancelled {
                _ = try? await mediator.send(RefreshAll())
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }

    deinit {
        task?.cancel()
    }
}
