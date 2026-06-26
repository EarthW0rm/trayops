import Foundation

/// Periodically dispatches ``RefreshAll`` so the platform state stays current
/// (every 15s in production; the interval is injectable for tests).
public final class StatePoller {
    private let mediator: Mediator
    private let intervalSeconds: TimeInterval
    private let logger: Logger
    private var task: Task<Void, Never>?

    public init(intervalSeconds: TimeInterval = 15, mediator: Mediator, logger: Logger = NullLogger()) {
        self.intervalSeconds = intervalSeconds
        self.mediator = mediator
        self.logger = logger
    }

    public func start() {
        stop()
        let mediator = self.mediator
        let logger = self.logger
        let nanoseconds = UInt64(intervalSeconds * 1_000_000_000)
        logger.info("state poller started (interval \(Int(intervalSeconds))s)")
        task = Task {
            while !Task.isCancelled {
                do {
                    try await mediator.send(RefreshAll())
                } catch {
                    logger.error("RefreshAll failed: \(error)")
                }
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
